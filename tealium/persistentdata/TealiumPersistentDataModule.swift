//
//  TealiumPersistentDataModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 10/7/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation

// MARK: 
// MARK: CONSTANTS

#if defaultsstorage
import TealiumCore
#elseif diskstorage
import TealiumCore
#endif

// MARK: 
// MARK: MODULE SUBCLASS

/// Module for adding publicly accessible persistence data capability.
class TealiumPersistentDataModule: TealiumModule {

    var persistentData: TealiumPersistentData?
    var diskStorage: TealiumDiskStorageProtocol!

    override class func moduleConfig() -> TealiumModuleConfig {
        return  TealiumModuleConfig(name: TealiumPersistentKey.moduleName,
                                    priority: 600,
                                    build: 2,
                                    enabled: true)
    }

    override func enable(_ request: TealiumEnableRequest) {
        isEnabled = true
        self.diskStorage = TealiumDiskStorage(config: request.config, forModule: TealiumPersistentKey.moduleName)
        self.persistentData = TealiumPersistentData(diskStorage: self.diskStorage)
        didFinish(request)
    }

    override func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        persistentData?.deleteAllData()
        persistentData = nil
        didFinish(request)
    }

    override func track(_ track: TealiumTrackRequest) {
        if self.isEnabled == false {
            didFinish(track)
            return
        }

        guard let persistentData = self.persistentData else {
            // Unable to load persistent data - continue with track call
            didFinish(track)
            return
        }

        guard persistentData.persistentDataCache.isEmpty == false else {
            // No custom persistent data to load
            didFinish(track)
            return
        }

        guard let data = persistentData.persistentDataCache.values() else {
            didFinish(track)
            return
        }

        var dataDictionary = [String: Any]()

        dataDictionary += data
        dataDictionary += track.trackDictionary
        let newTrack = TealiumTrackRequest(data: dataDictionary,
                                           completion: track.completion)

        didFinish(newTrack)
    }

}

//extension TealiumPersistentDataModule: TealiumPersistentDataDelegate {
//
//    func requestLoad(completion: @escaping TealiumCompletion) {
//        let request = TealiumLoadRequest(name: TealiumPersistentKey.moduleName,
//                                         completion: completion)
//        delegate?.tealiumModuleRequests(module: self,
//                                        process: request)
//    }
//
//    func requestSave(data: [String: Any]) {
//        let request = TealiumSaveRequest(name: TealiumPersistentKey.moduleName,
//                                         data: data)
//        delegate?.tealiumModuleRequests(module: self,
//                                        process: request)
//    }
//
//}
