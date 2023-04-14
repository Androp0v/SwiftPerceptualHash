//
//  File.swift
//  
//
//  Created by Raúl Montón Pinillos on 13/4/23.
//

import Foundation

public struct PerceptualHash {
    
    public let stringValue: String
    
    init(binaryString: String) {
        let number = binaryString.withCString {
            // String to Unsigned long
            strtoul($0, nil, 2)
        }
        self.stringValue = String(number, radix: 36, uppercase: false)
    }
}
