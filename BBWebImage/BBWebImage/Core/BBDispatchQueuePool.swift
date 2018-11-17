//
//  BBDispatchQueuePool.swift
//  BBWebImage
//
//  Created by Kaibo Lu on 2018/11/9.
//  Copyright © 2018年 Kaibo Lu. All rights reserved.
//

import UIKit

public class BBDispatchQueuePool {
    public static let userInteractive = BBDispatchQueuePool(label: "com.Kaibo.BBWebImage.QueuePool.userInteractive", qos: .userInteractive)
    public static let userInitiated = BBDispatchQueuePool(label: "com.Kaibo.BBWebImage.QueuePool.userInitiated", qos: .userInitiated)
    public static let utility = BBDispatchQueuePool(label: "com.Kaibo.BBWebImage.QueuePool.utility", qos: .utility)
    public static let `default` = BBDispatchQueuePool(label: "com.Kaibo.BBWebImage.QueuePool.default", qos: .default)
    public static let background = BBDispatchQueuePool(label: "com.Kaibo.BBWebImage.QueuePool.background", qos: .background)
    
    private let queues: [DispatchQueue]
    private var index: Int32
    
    public init(label: String, qos: DispatchQoS, queueCount: Int = 0) {
        let count = queueCount > 0 ? queueCount : min(16, max(1, ProcessInfo.processInfo.activeProcessorCount))
        var pool: [DispatchQueue] = []
        for i in 0..<count {
            let queue = DispatchQueue(label: "\(label).\(i)", qos: qos, target: DispatchQueue.global(qos: qos.qosClass))
            pool.append(queue)
        }
        queues = pool
        index = -1
    }
    
    public func async(work: @escaping () -> Void) {
        var currentIndex = OSAtomicIncrement32(&index)
        if currentIndex < 0 { currentIndex = -currentIndex }
        let queue = queues[Int(currentIndex) % queues.count]
        queue.async(execute: work)
    }
}
