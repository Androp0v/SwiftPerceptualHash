//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 13/4/23.
//

import Foundation

enum PerceptualHashError: Error {
    case metalDeviceCreationFailed
    case makeDefaultLibraryFailed
    case makeGrayscaleKernelFailed
    case makeGrayscalePSOFailed
    case createResizedTextureFailed(Int)
    case createGrayscaleResizedTextureFailed(Int)
    case makeCommandQueueFailed
}

extension PerceptualHashError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .metalDeviceCreationFailed:
            return "Metal device creation failed!"
        case .makeDefaultLibraryFailed:
            return "Unable to create default library!"
        case .makeGrayscaleKernelFailed:
            return "Failed to create grayscale kernel!"
        case .makeGrayscalePSOFailed:
            return "Failed to create grayscale pipeline state object!"
        case .createResizedTextureFailed(let size):
            return "Failed to create \(size)x\(size) resized texture."
        case .createGrayscaleResizedTextureFailed(let size):
            return "Failed to create \(size)x\(size) grayscale resized texture."
        case .makeCommandQueueFailed:
            return "Failed to create command queue!"
        }
    }
}
