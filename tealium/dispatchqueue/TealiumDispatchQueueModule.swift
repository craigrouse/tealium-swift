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

class TealiumDispatchQueueModule: TealiumModule {

    var persistentQueue: TealiumPersistentDispatchQueue?
    var maxQueueSize = TealiumDispatchQueueConstants.defaultMaxQueueSize
    var diskStorage: TealiumDiskStorageProtocol!
    let maxDispatchSize = 10

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
        releaseQueue(request)
        isEnabled = true
        didFinish(request)
    }

    override func handle(_ request: TealiumRequest) {
        if let request = request as? TealiumEnableRequest {
            enable(request)
        } else if let request = request as? TealiumDisableRequest {
            disable(request)
        } else if let request = request as? TealiumTrackRequest {
            track(request)
        } else if let request = request as? TealiumEnqueueRequest {
            queue(request)
        } else if let request = request as? TealiumReleaseQueuesRequest {
            releaseQueue(request)
        } else if let request = request as? TealiumClearQueuesRequest {
            clearQueue(request)
        } else {
            didFinishWithNoResponse(request)
        }
    }

    func queue(_ request: TealiumEnqueueRequest) {
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

    func clearQueue(_ request: TealiumRequest) {
        persistentQueue?.clearQueue()
    }

}

public extension TealiumConfig {
    func setMaxQueueSize(_ queueSize: Int) {
        optionalData[TealiumDispatchQueueConstants.queueSizeKey] = queueSize
    }
    func getMaxQueueSize() -> Int? {
        return optionalData[TealiumDispatchQueueConstants.queueSizeKey] as? Int
    }
}
