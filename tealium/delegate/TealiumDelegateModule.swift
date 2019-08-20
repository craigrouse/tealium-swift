//
//  TealiumDelegateModule.swift
//  tealium-swift
//
//  Created by Craig Rouse on 2/12/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if delegate
import TealiumCore
#endif

class TealiumDelegateModule: TealiumModule {

    var delegates: TealiumDelegates?

    override class  func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumDelegateKey.moduleName,
                                   priority: 900,
                                   build: 4,
                                   enabled: true)
    }

    override func enable(_ request: TealiumEnableRequest) {
        isEnabled = true

        delegates = request.config.delegates()
        delegate?.tealiumModuleRequests(module: self,
                                        process: TealiumReportNotificationsRequest())

        didFinishWithNoResponse(request)
    }

    /// Notifies listening delegates of a completed track request
    override func handleReport(_  request: TealiumRequest) {
        if let request = request as? TealiumTrackRequest {
            delegates?.invokeTrackCompleted(forTrackProcess: request)
        }
    }

    override func disable(_ request: TealiumDisableRequest) {
        delegates?.removeAll()
        delegates = nil
        didFinish(request)
    }

    /// Allows listening delegates to suppress a track request
    override func track(_ track: TealiumTrackRequest) {
        if delegates?.invokeShouldTrack(data: track.trackDictionary) == false {
            // Suppress the event from further processing
            track.completion?(false, nil, TealiumDelegateError.suppressedByShouldTrackDelegate)
            didFailToFinish(track,
                            error: TealiumDelegateError.suppressedByShouldTrackDelegate)
            return
        }
        didFinishWithNoResponse(track)
    }
}
