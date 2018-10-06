//
//  BBImageCoder.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/10/3.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public protocol BBImageCoder {
    func canDecode(imageData: Data) -> Bool
    func decode(imageData: Data) -> UIImage?
}

public class BBImageCoderManager {
    public var coders: [BBImageCoder] {
        willSet { coderLock.wait() }
        didSet { coderLock.signal() }
    }
    private let coderLock: DispatchSemaphore
    
    init() {
        coders = []
        coderLock = DispatchSemaphore(value: 1)
    }
}

extension BBImageCoderManager: BBImageCoder {
    public func canDecode(imageData: Data) -> Bool {
        coderLock.wait()
        let currentCoders = coders
        coderLock.signal()
        for coder in currentCoders {
            if coder.canDecode(imageData: imageData) { return true }
        }
        return false
    }
    
    public func decode(imageData: Data) -> UIImage? {
        coderLock.wait()
        let currentCoders = coders
        coderLock.signal()
        for coder in currentCoders {
            if coder.canDecode(imageData: imageData) {
                return coder.decode(imageData: imageData)
            }
        }
        return nil
    }
}