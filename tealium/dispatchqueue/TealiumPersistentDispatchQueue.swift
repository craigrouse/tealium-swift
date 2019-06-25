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
//    var queuedDispatches = [

    public init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
//        initializeQueue()
    }

//    func initializeQueue() {
//        diskStorage.retrieve(as: [TealiumTrackRequest].self) { _, data, _ in
//            guard let data = data else {
//
//                return
//            }
////            self.setLoadedAppData(data: data)
//        }
////        // queue already initialized
////        if let _ = TealiumPersistentDispatchQueue.queueStorage.object(forKey: storageKey) as? [[String: Any]] {
////            return
////        }
////        // init with blank data
////        let blankData = [[String: Any]]()
////        TealiumPersistentDispatchQueue.queueStorage.set(blankData, forKey: storageKey)
//    }

    func saveDispatch(_ dispatch: TealiumTrackRequest) {
        diskStorage.append(dispatch, completion: nil)
    }

    func peek() -> [TealiumTrackRequest]? {
//        return dequeueDispatches(clear: false)
        var trackRequests: [TealiumTrackRequest]?
        diskStorage.retrieve(as: [TealiumTrackRequest].self) { _, data, error in
            guard error == nil else {
                trackRequests = nil
                return
            }
            trackRequests = data
        }
        return trackRequests
    }

    func dequeueDispatches(clear clearQueue: Bool? = true) -> [TealiumTrackRequest]? {
        var queuedDispatches: [TealiumTrackRequest]?
//        readWriteQueue.read {
//            if let dispatches = TealiumPersistentDispatchQueue.queueStorage.array(forKey: self.storageKey) as? [[String: Any]] {
//                // clear persistent queue
//                if clearQueue == true {
//                    self.clearQueue()
//                }
//                queuedDispatches = dispatches
//            }
//        }
//        return queuedDispatches
        diskStorage.retrieve(as: [TealiumTrackRequest].self) { _, data, error in
            guard error == nil else {
                queuedDispatches = nil
                return
            }
            queuedDispatches = data
        }

        diskStorage.delete(completion: nil)

        return queuedDispatches
    }

    func removeOldDispatches(_ maxQueueSize: Int) {
        // save dispatch can only happen once queue is initialized
        guard let currentData = peek() else {
            return
        }

        // note: any completion blocks will be ignored for now, since we can only persist Dictionaries in UserDefaults
        var newData = currentData
        let totalDispatches = newData.count
        if totalDispatches == maxQueueSize {
            // take suffix to get most recent events and discard oldest first
            // want to remove only 1 event, so if current total is 20, max is 20, we want to be
            // left with 19 elements => 20 - (20-1) = 19
            let slice = newData.suffix(from: totalDispatches - (maxQueueSize - 1))
            newData = Array(slice)
//            readWriteQueue.write {
//                TealiumPersistentDispatchQueue.queueStorage.set(newData, forKey: self.storageKey)
//            }
        }
    }

    func clearQueue() {
//        readWriteQueue.write {
//            let blankData = [[String: Any]]()
//            TealiumPersistentDispatchQueue.queueStorage.set(blankData, forKey: self.storageKey)
//        }
    }

}
