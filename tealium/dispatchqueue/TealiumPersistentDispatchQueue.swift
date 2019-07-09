//
//  TealiumPersistentDispatchQueue.swift
//  tealium-swift
//
//  Created by Craig Rouse on 4/11/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if dispatchqueue
import TealiumCore
#endif

class TealiumPersistentDispatchQueue {

    private var diskStorage: TealiumDiskStorageProtocol!
    public var currentEvents: Int = 0

    public init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
        if let totalEvents = self.peek()?.count {
            self.currentEvents = totalEvents
        }

    }

    func saveDispatch(_ dispatch: TealiumTrackRequest) {
        // TODO: do something useful with completion
        currentEvents += 1
        diskStorage.append(dispatch, completion: nil)
    }

    func saveAndOverwrite(_ dispatches: [TealiumTrackRequest]) {
        // TODO: do something useful with completion
        currentEvents = dispatches.count
        diskStorage.save(dispatches, completion: nil)
    }

    func peek() -> [TealiumTrackRequest]? {
        guard let dispatches = dequeueDispatches(clear: false) else {
            return nil
        }
        currentEvents = dispatches.count
        return dispatches
    }

    func dequeueDispatches(clear clearQueue: Bool? = true) -> [TealiumTrackRequest]? {
        var queuedDispatches: [TealiumTrackRequest]?
        diskStorage.retrieve(as: [TealiumTrackRequest].self) { _, data, error in
            guard error == nil else {
                queuedDispatches = nil
                return
            }
            queuedDispatches = data
        }

        if clearQueue == true {
            self.currentEvents = 0
            diskStorage.delete(completion: nil)
        }

        return queuedDispatches
    }

    func removeOldDispatches(_ maxQueueSize: Int) {
        // save dispatch can only happen once queue is initialized
        guard let currentData = peek() else {
            return
        }

        // note: any completion blocks will be ignored for now, since we can only persist Dictionaries
        var newData = currentData
        let totalDispatches = newData.count
        if totalDispatches == maxQueueSize {
            // take suffix to get most recent events and discard oldest first
            // want to remove only 1 event, so if current total is 20, max is 20, we want to be
            // left with 19 elements => 20 - (20-1) = 19
            let slice = newData.suffix(from: totalDispatches - (maxQueueSize - 1))
            newData = Array(slice)
            self.saveAndOverwrite(newData)
        }
    }

    func clearQueue() {
        // TODO: do something useful with completion
        diskStorage.delete(completion: nil)
    }

}
