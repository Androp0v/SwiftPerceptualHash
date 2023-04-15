//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 15/4/23.
//

import Foundation
import Metal

extension PerceptualHashGenerator {
    
    /// Manages intermediate textures creation.
    internal actor IntermediateTextureHandler {
            
        var intermediateTextures = [IntermediateTextures]()
        
        var inUseTextures: [IntermediateTextures] {
            return intermediateTextures.filter({ $0.inUse == true })
        }
        var unusedTextures: [IntermediateTextures] {
            return intermediateTextures.filter({ $0.inUse == false })
        }
                        
        /// Creates or retrieves an unused set of `IntermediateTextures`.
        func getNext(
            generator: PerceptualHashGenerator,
            device: MTLDevice,
            resizedSize: Int,
            maxCommandBufferCount: Int
        ) throws -> IntermediateTextures {
            if let reusableTexture = inUseTextures.first {
                return reusableTexture
            }
            let newIntermediateTextures = try generator.createIntermediateTextures(
                device: device,
                resizedSize: resizedSize
            )
            self.intermediateTextures.append(newIntermediateTextures)
            return newIntermediateTextures
        }
        
        /// Removes references to existing sets of `IntermediateTextures` that are no longer in use.
        func freeUnused() {
            // If there's one or more textures in use, drop all unused textures
            if inUseTextures.count >= 1 {
                self.intermediateTextures = inUseTextures
                return
            }
            // Otherwise, drop all the unused textures except one
            if unusedTextures.count > 1 {
                self.intermediateTextures = unusedTextures.dropLast(unusedTextures.count - 1)
            }
        }
    }
}
