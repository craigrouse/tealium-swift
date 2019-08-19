//
//  TealiumAppDataModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 11/18/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation
#if appdata
import TealiumCore
#endif

/// Module to add app related data to track calls.
class TealiumAppDataModule: TealiumModule {

    var appData: TealiumAppDataProtocol!
    var diskStorage: TealiumDiskStorageProtocol!

    required public init(delegate: TealiumModuleDelegate?) {
        super.init(delegate: delegate)
    }

    init(delegate: TealiumModuleDelegate?, appData: TealiumAppDataProtocol) {
        super.init(delegate: delegate)
        self.appData = appData
    }

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumAppDataKey.moduleName,
                                   priority: 500,
                                   build: 3,
                                   enabled: true)
    }

    /// Enables the module and loads AppData into memory
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override func enable(_ request: TealiumEnableRequest) {
        diskStorage = TealiumDiskStorage(config: request.config, forModule: TealiumAppDataKey.moduleName, isCritical: true)
        appData = TealiumAppData(diskStorage: diskStorage)
        isEnabled = true

        didFinish(request)
    }

    /// Adds current AppData to the track request
    ///
    /// - parameter track: `TealiumTrackRequest` to be modified
    override func track(_ track: TealiumTrackRequest) {
        guard isEnabled == true else {
            // Ignore this module
            didFinishWithNoResponse(track)
            return
        }

        // do not add data to queued hits
        guard track.trackDictionary[TealiumKey.wasQueued] as? String == nil else {
            didFinishWithNoResponse(track)
            return
        }

        // Populate data stream
        var newData = [String: Any]()
        newData += appData.getData()
        newData += track.trackDictionary

        let newTrack = TealiumTrackRequest(data: newData,
                                           completion: track.completion)

        didFinish(newTrack)
    }

    /// Disables the module and deletes all associated data
    ///
    /// - parameter request: `TealiumDisableRequest`
    override func disable(_ request: TealiumDisableRequest) {
        appData.deleteAllData()
        isEnabled = false

        didFinish(request)
    }
}