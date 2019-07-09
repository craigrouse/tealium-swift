//
//  TealiumDispatchQueueConstants.swift
//  tealium-swift
//
//  Created by Craig Rouse on 4/27/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation

enum TealiumDispatchQueueConstants {
    static let defaultMaxQueueSize = 40
    static let moduleName = "dispatchqueue"
    // max stored events (e.g. if offline) to limit disk space consumed
    static let queueSizeKey = "queue_size"
    // number of events in a batch, max 10
    static let batchSizeKey = "batch_size"
    // dispatchEventLimit
    static let eventLimit = "event_limit"
    static let batchingEnabled = "batching_enabled"
}
