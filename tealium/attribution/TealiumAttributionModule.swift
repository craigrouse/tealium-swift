//
//  TealiumAttributionModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 11/16/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation
import UIKit
#if attribution
import TealiumCore
#endif
// TODO: check for ad group name typo (Christina)
/// Module to automatically add IDFA and IDFV to track calls. Does NOT work with watchOS.
class TealiumAttributionModule: TealiumModule {

    var attributionData: TealiumAttributionDataProtocol!
    var diskStorage: TealiumDiskStorageProtocol!

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumAttributionKey.moduleName,
                                   priority: 400,
                                   build: 3,
                                   enabled: true)
    }

    /// Provided for unit testing
    /// - parameter attributionData: Class instance conforming to `TealiumAttributionDataProtocol`
    convenience init (attributionData: TealiumAttributionDataProtocol) {
        self.init(delegate: nil)
        self.attributionData = attributionData
    }

    /// Module init
    /// - parameter delegate: TealiumModuleDelegate?
    required public init(delegate: TealiumModuleDelegate?) {
        super.init(delegate: delegate)
    }

    /// Enables the module and loads persistent attribution data into memory
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override func enable(_ request: TealiumEnableRequest) {
        diskStorage = TealiumDiskStorage(config: request.config, forModule: TealiumAttributionKey.moduleName)
        self.attributionData = TealiumAttributionData(diskStorage: diskStorage,
                                                      isSearchAdsEnabled: request.config.isSearchAdsEnabled())
        isEnabled = true
        didFinish(request)
    }

    /// Adds current AttributionData to the track request
    ///
    /// - parameter track: `TealiumTrackRequest` to be modified
    override func track(_ track: TealiumTrackRequest) {
        // Add idfa to data - NOTE: You must tell Apple why you are using this data when
        // submitting your app for review. See:
        // https://developer.apple.com/library/content/documentation/LanguagesUtilities/Conceptual/iTunesConnect_Guide/Chapters/SubmittingTheApp.html#//apple_ref/doc/uid/TP40011225-CH33-SW8

        guard isEnabled == true else {
            // Module disabled - ignore request
            didFinish(track)
            return
        }

        // do not add data to queued hits
        guard track.trackDictionary[TealiumKey.wasQueued] as? String == nil else {
            didFinishWithNoResponse(track)
            return
        }

        // Module enabled - add attribution info to data
        var newData = track.trackDictionary
        newData += attributionData.allAttributionData

        let newTrack = TealiumTrackRequest(data: newData,
                                           completion: track.completion)

        didFinish(newTrack)
    }

    /// Disables the module and deletes all associated data
    ///
    /// - parameter request: `TealiumDisableRequest`
    override func disable(_ request: TealiumDisableRequest) {
        self.isEnabled = false
        self.diskStorage.delete(completion: nil)
        didFinish(request)
    }
}
