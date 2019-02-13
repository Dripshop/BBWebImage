//
//  BBAnimatedImage.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2/6/19.
//  Copyright © 2019 Kaibo Lu. All rights reserved.
//

import UIKit

private struct BBAnimatedImageFrame {
    fileprivate var image: UIImage? {
        didSet {
            if let currentImage = image {
                size = currentImage.size
            }
        }
    }
    fileprivate var size: CGSize?
    fileprivate var duration: TimeInterval
    
    fileprivate var bytes: Int64? {
        if let currentSize = size { return Int64(currentSize.width * currentSize.height) }
        if let currentImage = image { return Int64(currentImage.size.width * currentImage.size.height) }
        return nil
    }
}

public class BBAnimatedImage: UIImage {
    private var frameCount: Int!
    public var bb_frameCount: Int { return frameCount }
    
    private var loopCount: Int!
    public var bb_loopCount: Int { return loopCount }
    
    private var maxCacheSize: Int64!
    private var currentCacheSize: Int64!
    private var autoUpdateMaxCacheSize: Bool!
    public var bb_maxCacheSize: Int64 {
        get { return maxCacheSize }
        set {
            if newValue >= 0 {
                maxCacheSize = newValue
                autoUpdateMaxCacheSize = false
            } else {
                maxCacheSize = 0
                autoUpdateMaxCacheSize = true
            }
        }
    }
    
    private var frames: [BBAnimatedImageFrame]!
    private var decoder: BBAnimatedImageCoder!
    private var lock: DispatchSemaphore!
    private var sentinel: Int32!
    private var preloadTask: (() -> Void)?
    
    deinit { cancelPreloadTask() }
    
    public convenience init?(bb_data data: Data, decoder aDecoder: BBAnimatedImageCoder? = nil) {
        var tempDecoder = aDecoder
        var canDecode = false
        if tempDecoder == nil {
            if let manager = BBWebImageManager.shared.imageCoder as? BBImageCoderManager {
                for coder in manager.coders {
                    if let animatedCoder = coder as? BBAnimatedImageCoder,
                        animatedCoder.canDecode(data) {
                        tempDecoder = animatedCoder
                        canDecode = true
                        break
                    }
                }
            }
        }
        guard let currentDecoder = tempDecoder else { return nil }
        if !canDecode && !currentDecoder.canDecode(data) { return nil }
        currentDecoder.imageData = data
        guard let firstFrame = currentDecoder.imageFrame(at: 0),
            let firstFrameSourceImage = firstFrame.cgImage,
            let currentFrameCount = currentDecoder.frameCount,
            currentFrameCount > 0 else { return nil }
        var imageFrames: [BBAnimatedImageFrame] = []
        for i in 0..<currentFrameCount {
            if let duration = currentDecoder.duration(at: i) {
                let image = (i == 0 ? firstFrame : nil)
                let size = currentDecoder.imageFrameSize(at: i)
                imageFrames.append(BBAnimatedImageFrame(image: image, size: size, duration: duration))
            } else {
                return nil
            }
        }
        self.init(cgImage: firstFrameSourceImage, scale: 1, orientation: firstFrame.imageOrientation)
        frameCount = currentFrameCount
        loopCount = currentDecoder.loopCount ?? 0
        maxCacheSize = Int64.max
        currentCacheSize = Int64(imageFrames.first!.bytes!)
        autoUpdateMaxCacheSize = true
        frames = imageFrames
        decoder = currentDecoder
        lock = DispatchSemaphore(value: 1)
        sentinel = 0
    }
    
    public func imageFrame(at index: Int) -> UIImage? {
        if index >= frameCount { return nil }
        lock.wait()
        let image = frames[index].image
        lock.signal()
        if image != nil { return image }
        return decoder.imageFrame(at: index)
    }
    
    public func duration(at index: Int) -> TimeInterval? {
        if index >= frameCount { return nil }
        lock.wait()
        let duration = frames[index].duration
        lock.signal()
        return duration
    }
    
    public func updateCacheSizeIfNeeded() {
        lock.wait()
        let autoUpdate = autoUpdateMaxCacheSize!
        lock.signal()
        if !autoUpdate { return }
        let total = Int64(Double(UIDevice.totalMemory) * 0.2)
        let free = Int64(Double(UIDevice.freeMemory) * 0.6)
        lock.wait()
        maxCacheSize = min(total, free)
        lock.signal()
    }
    
    public func preloadImageFrame(fromIndex startIndex: Int) {
        if startIndex >= frameCount { return }
        lock.wait()
        let shouldReturn = (preloadTask != nil)
        lock.signal()
        if shouldReturn { return }
        let sentinel = self.sentinel
        let work: () -> Void = { [weak self] in
            guard let self = self, sentinel == self.sentinel else { return }
            self.lock.wait()
            let cleanCache = (self.currentCacheSize > self.maxCacheSize)
            self.lock.signal()
            if cleanCache {
                for i in 0..<self.frameCount {
                    let index = (startIndex + self.frameCount * 2 - i - 2) % self.frameCount // last second frame of start index
                    var shouldBreak = false
                    self.lock.wait()
                    if self.frames[index].image != nil {
                        self.frames[index].image = nil
                        self.currentCacheSize -= self.frames[index].bytes ?? 0
                        shouldBreak = (self.currentCacheSize <= self.maxCacheSize)
                    }
                    self.lock.signal()
                    if shouldBreak { break }
                }
                return
            }
            for i in 0..<self.frameCount {
                let index = (startIndex + i) % self.frameCount
                self.lock.wait()
                let currentFrames = self.frames!
                self.lock.signal()
                if currentFrames[index].image == nil {
                    if let image = self.decoder.imageFrame(at: index) {
                        if sentinel != self.sentinel { return }
                        var shouldBreak = false
                        self.lock.wait()
                        if self.frames[index].image == nil {
                            if self.currentCacheSize + Int64(image.size.width * image.size.height) <= self.maxCacheSize {
                                self.frames[index].image = image
                                self.currentCacheSize += self.frames[index].bytes ?? 0
                            } else {
                                shouldBreak = true
                            }
                        }
                        self.lock.signal()
                        if shouldBreak { break }
                    }
                }
            }
            self.lock.wait()
            if sentinel == self.sentinel { self.preloadTask = nil }
            self.lock.signal()
        }
        lock.wait()
        preloadTask = work
        BBDispatchQueuePool.default.async(work: work)
        lock.signal()
    }
    
    private func cancelPreloadTask() {
        lock.wait()
        OSAtomicIncrement32(&sentinel)
        preloadTask = nil
        lock.signal()
    }
}
