//
//  BBWebImageGIFCoder.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2/6/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

import UIKit

public class BBWebImageGIFCoder: BBAnimatedImageCoder {
    private var imageSource: CGImageSource?
    private var imageOrientation: UIImage.Orientation
    
    public var imageData: Data? {
        didSet {
            if let data = imageData {
                imageSource = CGImageSourceCreateWithData(data as CFData, nil)
                if let source = imageSource,
                    let properties = CGImageSourceCopyProperties(source, nil) as? [CFString : Any],
                    let rawValue = properties[kCGImagePropertyOrientation] as? UInt32,
                    let orientation = CGImagePropertyOrientation(rawValue: rawValue) {
                    imageOrientation = orientation.toUIImageOrientation
                }
            } else {
                imageSource = nil
            }
        }
    }
    
    public var frameCount: Int? {
        if let source = imageSource {
            let count = CGImageSourceGetCount(source)
            if count > 0 { return count }
        }
        return nil
    }
    
    public var loopCount: Int? {
        if let source = imageSource,
            let properties = CGImageSourceCopyProperties(source, nil) as? [CFString : Any],
            let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString : Any],
            let count = gifInfo[kCGImagePropertyGIFLoopCount] as? Int {
            return count
        }
        return nil
    }
    
    public init() {
        imageOrientation = .up
    }
    
    public func imageFrame(at index: Int) -> UIImage? {
        if let source = imageSource,
            let sourceImage = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCache : true] as CFDictionary),
            let cgimage = BBWebImageImageIOCoder.decompressedImage(sourceImage) {
            return UIImage(cgImage: cgimage, scale: 1, orientation: imageOrientation)
        }
        return nil
    }
    
    public func duration(at index: Int) -> TimeInterval? {
        if let source = imageSource,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString : Any],
            let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString : Any] {
            var currentDuration: TimeInterval = -1
            if let d = gifInfo[kCGImagePropertyGIFUnclampedDelayTime] as? TimeInterval {
                currentDuration = d
            } else if let d = gifInfo[kCGImagePropertyGIFDelayTime] as? TimeInterval {
                currentDuration = d
            }
            if currentDuration >= 0 {
                if currentDuration < 0.01 { currentDuration = 0.1 }
                return currentDuration
            }
        }
        return nil
    }
}

extension BBWebImageGIFCoder: BBImageCoder {
    public func canDecode(_ data: Data) -> Bool {
        return data.bb_imageFormat == .GIF
    }
    
    public func decodedImage(with data: Data) -> UIImage? {
        return BBAnimatedImage(bb_data: data, decoder: copy() as? BBAnimatedImageCoder)
    }
    
    public func decompressedImage(with image: UIImage, data: Data) -> UIImage? {
        return nil
    }
    
    public func canEncode(_ format: BBImageFormat) -> Bool {
        // TODO: Encode gif
        return false
    }
    
    public func encodedData(with image: UIImage, format: BBImageFormat) -> Data? {
        // TODO: Encode gif
        return nil
    }
    
    public func copy() -> BBImageCoder {
        return BBWebImageGIFCoder()
    }
}