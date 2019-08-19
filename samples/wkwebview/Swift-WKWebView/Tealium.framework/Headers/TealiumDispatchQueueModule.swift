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

class TealiumDispatchQueueModule: TealiumModule {

    var persistentQueue: TealiumPersistentDispatchQueue!
    var diskStorage: TealiumDiskStorageProtocol!
    // when to start trimming the queue (default 20) - e.g. if offline
    var maxQueueSize = TealiumDispatchQueueConstants.defaultMaxQueueSize
     // max number of events in a single batch
    var maxDispatchSize = TealiumValue.maxEventBatchSize
    var eventsBeforeAutoDispatch: Int!
    var isBatchingEnabled = true
    var batchingBypassKeys: [String]?

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumDispatchQueueConstants.moduleName,
                                   priority: 1000,
                                   build: 1,
                                   enabled: true)
    }

    override func enable(_ request: TealiumEnableRequest) {
        batchingBypassKeys = request.config.getBatchingBypassKeys()
        diskStorage = TealiumDiskStorage(config: request.config, forModule: TealiumDispatchQueueConstants.moduleName)
        persistentQueue = TealiumPersistentDispatchQueue(diskStorage: diskStorage)
        // release any previously-queued track requests
        if let maxSize = request.config.getMaxQueueSize() {
            maxQueueSize = maxSize
        }
        removeOldDispatches()
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
        removeOldDispatches()
        let allTrackRequests = request.data

        allTrackRequests.forEach {
            var newData = $0.trackDictionary
            newData[TealiumKey.wasQueued] = "true"
            let newTrack = TealiumTrackRequest(data: newData,
                                               completion: $0.completion)
            persistentQueue?.saveDispatch(newTrack)
        }
    }

    func removeOldDispatches() {
        let currentDate = Date()
        var components = DateComponents()
        components.calendar = Calendar.autoupdatingCurrent
        // TODO: make this configurable
        components.setValue(-7, for: .day)
        let sinceDate = Calendar(identifier: .gregorian).date(byAdding: components, to: currentDate)
        persistentQueue?.removeOldDispatches(maxQueueSize, since: sinceDate)
    }

    func releaseQueue(_ request: TealiumRequest) {
        if let queuedDispatches = persistentQueue?.dequeueDispatches() {
            let batches: [[TealiumTrackRequest]] = queuedDispatches.chunks(maxDispatchSize)

            batches.forEach { batch in

                switch batch.count {
                case let val where val <= 1:
                    if let data = batch.first?.trackDictionary {
                        let request = TealiumTrackRequest(data: data, completion: nil)
                        // TODO: Why doesn't this work without a delay?
                        TealiumQueues.backgroundSerialQueue.asyncAfter(deadline: DispatchTime.now() + 1) {
                            self.delegate?.tealiumModuleRequests(module: self,
                                                                 process: request)
                        }
                    }

                case let val where val > 1:
                    let batchRequest = TealiumBatchTrackRequest(trackRequests: batch, completion: nil)
                    // TODO: Why doesn't this work without a delay?
                    TealiumQueues.backgroundSerialQueue.asyncAfter(deadline: DispatchTime.now() + 1) {
                        self.delegate?.tealiumModuleRequests(module: self,
                                                             process: batchRequest)
                    }
                default:
                    print("")
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

        let canWrite = diskStorage.canWrite()
        // make sure batching is enabled and configured to send > 1 event, otherwise dispatch immediately
        if isBatchingEnabled, eventsBeforeAutoDispatch > 1, maxDispatchSize > 1, maxQueueSize > 1,
            canWrite, canQueueRequest(request) {
            var requestData = request.trackDictionary
            requestData[TealiumKey.queueReason] = TealiumDispatchQueueConstants.batchingEnabled
            requestData[TealiumKey.wasQueued] = "true"
            let newRequest = TealiumTrackRequest(data: requestData, completion: request.completion)
            persistentQueue.saveDispatch(newRequest)
            logQueue(request: newRequest)
        } else {
            if !canWrite {
                let report = TealiumReportRequest(message: "Insufficient disk storage available. Event Batching has been disabled.")
                delegate?.tealiumModuleRequests(module: self, process: report)
            }
            self.didFinishWithNoResponse(request)
        }
    }

    func logQueue(request: TealiumTrackRequest) {
        let message = """
        \n=====================================
        ⏳ Event: \(request.trackDictionary[TealiumKey.event] as? String ?? "") queued for batch dispatch
        =====================================\n
        """
        let report = TealiumReportRequest(message: message)
        delegate?.tealiumModuleRequests(module: self, process: report)
    }

    func canQueueRequest(_ request: TealiumTrackRequest) -> Bool {
        guard let event = request.event() else {
            return false
        }
        var shouldQueue = true
        for key in BypassDispatchQueueKeys.allCases where key.rawValue == event {
                shouldQueue = false
                break
        }

        if let batchingBypassKeys = batchingBypassKeys {
            for key in batchingBypassKeys where key == event {
                shouldQueue = false
                break
            }
        }

        return shouldQueue
    }

}