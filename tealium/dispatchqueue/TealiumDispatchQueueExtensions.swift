//
//  TealiumDispatchQueueExtensions.swift
//  tealium-swift
//
//  Created by Craig Rouse on 22/07/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public extension TealiumConfig {
    func setBatchSize(_ size: Int) {
        let size = size > TealiumValue.maxEventBatchSize ? TealiumValue.maxEventBatchSize: size
        optionalData[TealiumDispatchQueueConstants.batchSizeKey] = size
    }

    func getBatchSize() -> Int {
        return optionalData[TealiumDispatchQueueConstants.batchSizeKey] as? Int ?? TealiumValue.maxEventBatchSize
    }

    func setDispatchAfter(numberOfEvents events: Int) {
        optionalData[TealiumDispatchQueueConstants.eventLimit] = events
    }

    func getDispatchAfterEvents() -> Int? {
        return optionalData[TealiumDispatchQueueConstants.eventLimit] as? Int
    }

    func setMaxQueueSize(_ queueSize: Int) {
        optionalData[TealiumDispatchQueueConstants.queueSizeKey] = queueSize
    }

    func getMaxQueueSize() -> Int? {
        return optionalData[TealiumDispatchQueueConstants.queueSizeKey] as? Int
    }

    func setIsEventBatchingEnabled(_ enabled: Bool) {
        // batching requires disk storage
        guard isDiskStorageEnabled() == true else {
            optionalData[TealiumDispatchQueueConstants.batchingEnabled] = false
            return
        }
        optionalData[TealiumDispatchQueueConstants.batchingEnabled] = enabled
    }

    func getIsEventBatchingEnabled() -> Bool {
        // batching requires disk storage
        guard isDiskStorageEnabled() == true else {
            return false
        }
        return optionalData[TealiumDispatchQueueConstants.batchingEnabled] as? Bool ?? true
    }

    func setBatchingBypassKeys(_ keys: [String]) {
        self.optionalData[TealiumDispatchQueueConstants.batchingBypassKeys] = keys
    }

    func getBatchingBypassKeys() -> [String]? {
        return self.optionalData[TealiumDispatchQueueConstants.batchingBypassKeys] as? [String]
    }

    func setBatchExpirationDays(_ days: Int) {
        self.optionalData[TealiumDispatchQueueConstants.batchExpirationDaysKey] = days
    }

    func getBatchExpirationDays() -> Int {
        return self.optionalData[TealiumDispatchQueueConstants.batchExpirationDaysKey] as? Int ?? TealiumDispatchQueueConstants.defaultBatchExpirationDays
    }

}
