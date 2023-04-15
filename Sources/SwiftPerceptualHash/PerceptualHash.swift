//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 13/4/23.
//

import Foundation


/// A `PerceptualHash` is a hash used to compare how similar two images are. Two images are
/// identical if their hashes are the same. Similar images will have similar hashes, and completely
/// different images will have completely different hashes.
///
/// As with any hashing algorithm, collisions can happen, where two completely different images end
/// up with the same hash. This happens because, while there's an infinite number of images, a
/// `PerceptualHash` has a fixed number of bits to represent all of them.
///
/// Two hashes can only be compared if they have been generated using the same
/// `PerceptualHashGenerator` configuration.
public struct PerceptualHash: Equatable {
    
    public let numberOfBits: Int
    public let blocks: [UInt64]
    
    // MARK: - Strings
    
    /// A string representation of the perceptual hash, in its most compact form (i.e. "40ixng9r").
    public var stringValue: String {
        var finalString = ""
        for block in blocks {
            finalString.append(String(block, radix: 36, uppercase: false))
        }
        return finalString
    }
    /// A binary representation of the perceptual hash (i.e. "100100100111111101101101111101100011111").
    public var binaryString: String {
        var finalString = ""
        for block in blocks {
            finalString.append(String(block, radix: 2))
        }
        return finalString
    }
    /// A hexadecimal representation of the perceptual hash (i.e. "493FB6FB1F").
    public var hexString: String {
        var finalString = ""
        for block in blocks {
            finalString.append(String(block, radix: 16, uppercase: true))
        }
        return finalString
    }
    
    // MARK: - Init
    
    /// You typically don't call this initializer directly. Instead, you use a method from the `PerceptualHashGenerator`
    /// class to get a object of this type.
    /// - Parameter binaryString: A binary representation of the perceptual hash (i.e. "1001001").
    public init(binaryString: String) {
        
        var blocks = [UInt64]()
        
        // Get the number of characters in the string. Since each character
        // represents a bit, that means that this is also the number of bits.
        let numberOfBits = binaryString.count
        
        // Divide the string in blocks of 64 characters (bits).
        
        // Number of blocks with full 64-bit numbers
        let fullBlockCount = numberOfBits / 64
        
        // The string size might not be a multiple of 64
        let remainder = numberOfBits % 64
        
        // Convert the most significant bits (less than or 64) to a UInt64
        let remainderIndex = binaryString.index(binaryString.startIndex, offsetBy: remainder)
        if remainder != 0 {
            let remainderString = binaryString[..<remainderIndex]
            blocks.append(UInt64(remainderString, radix: 2)!)
        }
        
        // Convert all the other 64-bit blocks to UInt64
        var blockStartIndex = remainderIndex
        for _ in 0..<fullBlockCount {
            let blockEndIndex = binaryString.index(blockStartIndex, offsetBy: 64)
            let blockString = binaryString[blockStartIndex..<blockEndIndex]
            blocks.append(UInt64(blockString, radix: 2)!)
            blockStartIndex = blockEndIndex
        }
        
        // Save the blocks
        self.numberOfBits = numberOfBits
        self.blocks = blocks
    }
}

// MARK: - Comparison

/// The difference between two hashes, using the Hamming distance.
///
/// Values range from `0.0` (most dissimilar) to `1.0` (identical).
/// Hashes generated with different configurations that maintain the same number of bits (like
/// a different `resizedSize` in `PerceptualHashGenerator`) are not comparable,
/// but no error will be thrown.
/// - Parameters:
///   - lhs: The first `PerceptualHash`.
///   - rhs: The second `PerceptualHash`.
/// - Throws: Both hashes must have the same number of bits, or an error will be thrown.
/// - Returns: The similarity between the two hashes. A value of `1.0` means that the
/// hashes are identical, while a value of `0.0` means the two hashes are as different from
/// each other as possible.
public func similarity(_ lhs: PerceptualHash, _ rhs: PerceptualHash) throws -> Double {
    
    // Make sure that the left hand side and right hand side have the
    // same number of bits.
    guard lhs.numberOfBits == rhs.numberOfBits else {
        throw PerceptualHashError.numberOfBitsMismatch
    }
    
    // Set a counter for the number of bits that are different.
    var differingBitCounter = 0
    
    // Iterate over all the stored blocks
    for i in 0..<lhs.blocks.count {
        var differentBits = lhs.blocks[i] ^ rhs.blocks[i]
        while differentBits > 0 {
            let maskedBits = differentBits & 1
            if maskedBits != 0 {
                differingBitCounter += 1
            }
            // Right-shift bits to test next bit.
            differentBits = differentBits >> 1
        }
    }
    return 1.0 - Double(differingBitCounter) / Double(lhs.numberOfBits)
}
