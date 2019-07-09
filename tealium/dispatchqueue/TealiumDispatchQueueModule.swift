//
//  TealiumDispatchQueueModule.swift
//  tealium-swift
//
//  Created by Craig Rouse on 4/9/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if dispatchqueue
import TealiumCore
#endif

// TODO:
// Lifecycle Listener: Flush queue when app is terminated

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
        optionalData[TealiumDispatchQueueConstants.batchingEnabled] = enabled
    }

    func getIsEventBatchingEnabled() -> Bool {
        return optionalData[TealiumDispatchQueueConstants.batchingEnabled] as? Bool ?? true
    }

}

class TealiumDispatchQueueModule: TealiumModule {

    var persistentQueue: TealiumPersistentDispatchQueue!
    var diskStorage: TealiumDiskStorageProtocol!
    // when to start trimming the queue (default 20) - e.g. if offline
    var maxQueueSize = TealiumDispatchQueueConstants.defaultMaxQueueSize
     // max number of events in a single batch
    var maxDispatchSize = TealiumValue.maxEventBatchSize
    var eventsBeforeAutoDispatch: Int!
    var isBatchingEnabled = true

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumDispatchQueueConstants.moduleName,
                                   priority: 1000,
                                   build: 1,
                                   enabled: true)
    }

    override func enable(_ request: TealiumEnableRequest) {
        diskStorage = TealiumDiskStorage(config: request.config, forModule: TealiumDispatchQueueConstants.moduleName)
        persistentQueue = TealiumPersistentDispatchQueue(diskStorage: diskStorage)
        // release any previously-queued track requests
        if let maxSize = request.config.getMaxQueueSize() {
            maxQueueSize = maxSize
        }

        self.eventsBeforeAutoDispatch = request.config.getDispatchAfterEvents()
        self.maxDispatchSize = request.config.getBatchSize()
        self.isBatchingEnabled = request.config.getIsEventBatchingEnabled()

        // always release queue at launch
        releaseQueue(request)
        isEnabled = true
        didFinish(request)
    }

    override func handle(_ request: TealiumRequest) {
        switch request {
        case let request as TealiumEnableRequest:
            enable(request)
        case let request as TealiumDisableRequest:
            disable(request)
        case let request as TealiumTrackRequest:
            track(request)
        case let request as TealiumEnqueueRequest:
            queue(request)
        case let request as TealiumReleaseQueuesRequest:
            releaseQueue(request)
        case let request as TealiumClearQueuesRequest:
            clearQueue(request)
        default:
            didFinishWithNoResponse(request)
        }
    }

    func queue(_ request: TealiumEnqueueRequest) {
        // TODO: optimize this into the save
        removeOldDispatches()
        let track = request.data
        var newData = track.trackDictionary
        newData[TealiumKey.wasQueued] = "true"
        let newTrack = TealiumTrackRequest(data: newData,
                                           completion: track.completion)
        persistentQueue?.saveDispatch(newTrack)
    }

    func removeOldDispatches() {
        persistentQueue?.removeOldDispatches(maxQueueSize)
    }

    func releaseQueue(_ request: TealiumRequest) {
        if let queuedDispatches = persistentQueue?.dequeueDispatches() {
            let batches: [[TealiumTrackRequest]] = queuedDispatches.chunks(maxDispatchSize)

            batches.forEach { batch in
                let batchRequest = TealiumBatchTrackRequest(trackRequests: batch, completion: nil)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
                    self.delegate?.tealiumModuleRequests(module: self,
                                                         process: batchRequest)
                }
            }
        }
    }

    func releaseQueue() {
        let releaseRequest = TealiumReleaseQueuesRequest(typeId: "dispatchqueue", moduleResponses: [], completion: nil)
        releaseQueue(releaseRequest)
    }

    func clearQueue(_ request: TealiumRequest) {
        persistentQueue?.clearQueue()
    }

    override func track(_ request: TealiumTrackRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(request)
            return
        }

        if persistentQueue.currentEvents >= self.eventsBeforeAutoDispatch {
            self.releaseQueue()
        }

        // make sure batching is enabled and configured to send > 1 event, otherwise dispatch immediately
        if isBatchingEnabled, eventsBeforeAutoDispatch > 1, maxDispatchSize > 1, maxQueueSize > 1 {
            persistentQueue.saveDispatch(request)
        } else {
            self.didFinishWithNoResponse(request)
        }

    }

}
