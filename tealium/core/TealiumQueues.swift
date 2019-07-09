//
//  TealiumQueues.swift
//  tealium-swift
//
//  Created by Craig Rouse on 27/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

class TealiumQueues {
//    fileprivate static let backgroundConcurrentQueue: DispatchQueue = {
//        let queue = DispatchQueue(label: "com.tealium.backgroundqueue", qos: .background, attributes: [.concurrent], autoreleaseFrequency: .inherit, target: .global(qos: .background))
//        queue.setSpecific(key: DispatchSpecificKey(), value: "com.tealium.backgroundqueue")
//        return queue
//    }()

    public static let backgroundConcurrentQueue = {
        return ReadWrite("com.tealium.backgroundconcurrentqueue")
    }()

    static let mainQueue = DispatchQueue.main

    static let backgroundSerialQueue = DispatchQueue(label: "com.tealium.backgroundserialqueue", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: .global(qos: .background))

//    public static func submitWork(execute work: @escaping @convention(block) () -> Void) {
//        backgroundConcurrentQueue.async(flags: .barrier) {
//            work()
//        }
//    }

}

public extension DispatchQueue {
    static var currentLabel: String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }
}
