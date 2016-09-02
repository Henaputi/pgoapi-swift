//
//  Extensions.swift
//  pgomap
//
//  Created by Luke Sapan on 7/20/16.
//  Copyright © 2016 Coadstal. All rights reserved.
//

import Foundation


internal extension NSRange {
    func rangeForString(str: String) -> Range<String.Index>? {
        guard location != NSNotFound else { return nil }
        return str.startIndex.advancedBy(location) ..< str.startIndex.advancedBy(location + length)
    }
}

internal extension NSData {
    public func getUInt8Array() -> Array<UInt8> {
        return Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(self.bytes), count: self.length))
    }
    public func getUInt32Array() -> Array<UInt32> {
        return Array(UnsafeBufferPointer(start: UnsafePointer<UInt32>(self.bytes), count: self.length))
    }
    public var getHexString: String {
        var bytes = [UInt8](count: length, repeatedValue: 0)
        getBytes(&bytes, length: length)
        
        let hexString = NSMutableString()
        for byte in bytes {
            hexString.appendFormat("%02x", UInt(byte))
        }
        
        return String(hexString)
    }
    public static func randomBytes(len: Int? = 32) -> NSData {
        var randomBytes = [UInt8](count: len!, repeatedValue: 0)
        SecRandomCopyBytes(kSecRandomDefault, len!, &randomBytes)
        return NSData(bytes: randomBytes, length: len!)
    }
}

internal extension Float {
    public static var random:Float {
        get {
            return Float(arc4random()) / 0xFFFFFFFF
        }
    }
    public static func random(min min: Float, max: Float) -> Float {
        return Float.random * (max - min) + min
    }
}