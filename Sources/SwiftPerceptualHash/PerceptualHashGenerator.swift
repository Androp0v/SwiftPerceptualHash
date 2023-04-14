//
//  PerceptualHash.swift
//  SwiftPerceptualHash
//
//  Created by Raúl Montón Pinillos on 12/4/23.
//

import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders

/// Class used to generate a `PerceptualHash`. A `PerceptualHash` is a hash used to
/// compare how similar two images are. Two images are identical if their hashes are the same.
/// Similar images will have similar hashes, and completely different images will have completely
/// different hashes.
///
/// Create a `PerceptualHashGenerator` once, and reuse it throughout the app. Initializing
/// this class creates a bunch of Metal objects that are expensive to create but can be reused to
/// compute hashes for different images.
public class PerceptualHashGenerator {
    
    /// The size of the DCT matrix used to generate the hash. A hash will require `pow(dctSize,2)`
    /// bits to be stored. Defaults to a 8x8 matrix, to generate 64-bit hashes.
    public let dctSize: Int
    /// The size the image will be resized to before the DCT is computed. Defaults to a 32x32 image.
    public let resizedSize: Int
    
    /// The system's default Metal device.
    private let device: MTLDevice
    /// The command queue.
    private let commandQueue: MTLCommandQueue
    /// The Pipeline State Object of a grayscale kernel.
    private let grayscalePSO: MTLComputePipelineState
    /// Used to load a `MTLTexture` from image data.
    private let textureLoader: MTKTextureLoader
    /// The intermediate, resized image texture used to compute the DCT.
    private let resizedTexture: MTLTexture
    /// The intermediate, resized image texture used to compute the DCT, in grayscale.
    private let grayscaleTexture: MTLTexture
    
    // MARK: - Initialization
    
    /// Initializes a `PerceptualHashGenerator` with a specific configuration.
    /// - Parameters:
    ///   - resizedSize: The size the image will be resized to before the DCT is computed.
    ///   Defaults to a 32x32 image. Bigger sizes can allow for more precise image comparisons,
    ///   as more high-frequency data is preserved.
    ///   - dctSize: The size of the DCT matrix used to generate the hash. Bigger sizes can
    ///   allow for more precise image comparisons, as more high-frequency data is preserved.
    public init(resizedSize: Int = 32, dctSize: Int = 8) throws {
        
        // Check against wrong parameter configurations
        guard resizedSize > 0 else {
            throw PerceptualHashError.negativeOrZeroResizedSize
        }
        guard dctSize > 1 else {
            throw PerceptualHashError.wrongDCTSize
        }
        guard resizedSize >= dctSize else {
            throw PerceptualHashError.resizedSizeTooSmallForDCTSize
        }
        self.resizedSize = resizedSize
        self.dctSize = dctSize
        
        // Get Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw PerceptualHashError.metalDeviceCreationFailed
        }
        self.device = device
        
        // Get the default library
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            throw PerceptualHashError.makeDefaultLibraryFailed
        }
        
        // Create the grayscale kernel function
        guard let grayscaleKernel = defaultLibrary.makeFunction(name: "grayscale_kernel") else {
            throw PerceptualHashError.makeGrayscaleKernelFailed
        }
        
        // Create the grayscale Pipeline State Object
        guard let grayscalePSO = try? device.makeComputePipelineState(function: grayscaleKernel) else {
            throw PerceptualHashError.makeGrayscalePSOFailed
        }
        self.grayscalePSO = grayscalePSO
        
        // Create a texture loader
        self.textureLoader = MTKTextureLoader(device: device)
        
        // Create small intermediate texture
        let resizedTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: resizedSize,
            height: resizedSize,
            mipmapped: false
        )
        resizedTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let resizedTexture = device.makeTexture(descriptor: resizedTextureDescriptor) else {
            throw PerceptualHashError.createResizedTextureFailed(resizedSize)
        }
        self.resizedTexture = resizedTexture
        
        // Create small intermediate texture (grayscale)
        let grayscaleTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: resizedSize,
            height: resizedSize,
            mipmapped: false
        )
        grayscaleTextureDescriptor.usage = [.shaderRead, .shaderWrite]
        guard let grayscaleTexture = device.makeTexture(descriptor: grayscaleTextureDescriptor) else {
            throw PerceptualHashError.createGrayscaleResizedTextureFailed(resizedSize)
        }
        self.grayscaleTexture = grayscaleTexture
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw PerceptualHashError.makeCommandQueueFailed
        }
        self.commandQueue = commandQueue
    }
    
    // MARK: - Hash
    
    /// Creates a `PerceptualHash` for an image using its raw data.
    /// - Parameter imageData: The raw data for the image.
    /// - Returns: A `PerceptualHash` object, used to check how similar two images are.
    public func perceptualHash(imageData: Data) async throws -> PerceptualHash? {
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer!")
            return nil
        }
        
        // Create the source image texture
        var sourceImageTexture = try await self.textureLoader.newTexture(
            data: imageData,
            options: [
                MTKTextureLoader.Option.textureUsage: MTLTextureUsage.unknown.rawValue,
                MTKTextureLoader.Option.textureStorageMode: MTLStorageMode.shared.rawValue
            ]
        )
        
        // Compute the x and y axis scales required to resize the image
        let scaleX = Double(resizedSize) / Double(sourceImageTexture.width)
        let scaleY = Double(resizedSize) / Double(sourceImageTexture.height)
        
        // MARK: - Gaussian blur
        
        // Blur the image to get rid of all the high-frequency features that could
        // result in aliasing in the downsampled image
        let blur = MPSImageGaussianBlur(device: device, sigma: Float(1 / (2 * min(scaleX, scaleY))))
        withUnsafeMutablePointer(to: &sourceImageTexture) { texturePointer in
            _ = blur.encode(commandBuffer: commandBuffer, inPlaceTexture: texturePointer)
        }
        
        // MARK: - Resize
        
        // Resize the image to target 32x32 resolution
        let resize = MPSImageBilinearScale(device: device)
        var transform = MPSScaleTransform(
            scaleX: scaleX,
            scaleY: scaleY,
            translateX: 0.0,
            translateY: 0.0
        )
        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
            resize.scaleTransform = transformPtr
        }
        resize.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceImageTexture,
            destinationTexture: resizedTexture
        )
        
        // MARK: - Grayscale
        
        // Create compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("Failed to create compute command encoder!")
            return nil
        }
        
        // Set the PSO to perform a grayscale conversion
        computeEncoder.setComputePipelineState(grayscalePSO)
        
        // Set the source texture
        computeEncoder.setTexture(resizedTexture, index: 0)
        
        // Set the output texture
        computeEncoder.setTexture(grayscaleTexture, index: 1)
        
        // Dispatch the threads
        let threadgroupSize = MTLSizeMake(16, 16, 1)
        var threadgroupCount = MTLSize()
        threadgroupCount.width  = (resizedTexture.width + threadgroupSize.width - 1) / threadgroupSize.width
        threadgroupCount.height = (resizedTexture.height + threadgroupSize.height - 1) / threadgroupSize.height
        // The image data is 2D, so set depth to 1
        threadgroupCount.depth = 1
        computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        
        // Finish encoding
        computeEncoder.endEncoding()
        
        // MARK: - Finish
        
        let binaryStringHash = await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                let binaryStringHash = self.computeDCT(grayscaleTexture: self.grayscaleTexture)
                continuation.resume(returning: binaryStringHash)
            }
            // Submit work to the GPU
            commandBuffer.commit()
        }
        return PerceptualHash(binaryString: binaryStringHash)
    }
    
    // MARK: - Compute DCT
    
    private func computeDCT(grayscaleTexture: MTLTexture) -> String {
        let rowBytes = resizedSize * 4
        let length = rowBytes * resizedSize
        let region = MTLRegionMake2D(0, 0, resizedSize, resizedSize)
        var grayBytes = [Float32](repeating: 0, count: length)
        var dctArray = [Float](repeating: 0, count: dctSize * dctSize)
        
        var binaryHash: String = ""
        
        // Fill with the texture data
        grayBytes.withUnsafeMutableBytes { r32BytesPointer in
            guard let baseAddress = r32BytesPointer.baseAddress else {
                return
            }
            // Fill the array with data from the grayscale texture
            grayscaleTexture.getBytes(
                baseAddress,
                bytesPerRow: rowBytes,
                from: region,
                mipmapLevel: 0
            )
        }
        // Compute each one of the elements of the discrete cosine transform
        for u in 0..<dctSize {
            for v in 0..<dctSize {
                var pixel_sum: Float = 0
                for i in 0..<resizedSize {
                    var pixel_row_sum: Float = 0
                    // Compute the discrete cosine along the row axis
                    for j in 0..<resizedSize {
                        let pixelValue = grayBytes[i * resizedSize + j]
                        pixel_row_sum += pixelValue
                            * cos((Float.pi * (2.0 * Float(j) + 1.0) * Float(u)) / (2.0 * Float(resizedSize)))
                    }
                    pixel_row_sum *= cos((Float.pi * (2.0 * Float(i) + 1.0) * Float(v)) / (2.0 * Float(resizedSize)))
                    pixel_sum += pixel_row_sum
                }
                if u != 0 {
                    pixel_sum *= sqrt(2/Float(resizedSize))
                } else {
                    pixel_sum += sqrt(1/Float(resizedSize))
                }
                if v != 0 {
                    pixel_sum *= sqrt(2/Float(resizedSize))
                } else {
                    pixel_sum += sqrt(1/Float(resizedSize))
                }
                dctArray[u * dctSize + v] = pixel_sum
            }
        }
        
        // Remove zero order value at (0,0), as it throws off the mean
        dctArray[0] = 0.0
        
        // Compute the mean of all the elements in the image
        var meanDCT: Float = 0.0
        for u in 0..<dctSize {
            for v in 0..<dctSize {
                let dctValue = dctArray[u * dctSize + v]
                meanDCT += dctValue
            }
        }
        meanDCT /= Float(dctSize * dctSize)
        
        // Compute the hash comparing with the mean
        for i in 0..<(dctSize * dctSize) {
            if dctArray[i] > Float32(meanDCT) {
                binaryHash += "1"
            } else {
                binaryHash += "0"
            }
        }
        return binaryHash
    }
}

