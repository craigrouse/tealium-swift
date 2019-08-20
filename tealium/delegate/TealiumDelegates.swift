//
//  TealiumDelegates.swift
//  tealium-swift
//
//  Created by Craig Rouse on 20/08/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation
#if delegate
import TealiumCore
#endif

public class TealiumDelegates {
    // swiftlint:disable weak_delegate
    var multicastDelegate = TealiumMulticastDelegate<TealiumDelegate>()
    // swiftlint:enable weak_delegate

    /// Add a weak pointer to a class conforming to the TealiumDelegate protocol.
    ///
    /// - parameter delegate: Class conforming to the TealiumDelegate protocols.
    public func add(delegate: TealiumDelegate) {
        multicastDelegate.add(delegate)
    }

    /// Remove the weaker pointer reference to a given class from the multicast
    ///   delegates handler.
    ///
    /// - parameter delegate: Class conforming to the TealiumDelegate protocols.
    public func remove(delegate: TealiumDelegate) {
        multicastDelegate.remove(delegate)
    }

    /// Remove all weak pointer references to classes conforming to the TealiumDelegate
    ///   protocols from the multicast delgate handler.
    public func removeAll() {
        multicastDelegate.removeAll()
    }

    /// Query all delegates if the data should be tracked or suppressed.
    ///
    /// - parameter data: Data payload to inspect
    /// - returns: True if all delegates approve
    public func invokeShouldTrack(data: [String: Any]) -> Bool {
        var shouldTrack = true
        multicastDelegate.invoke { if $0.tealiumShouldTrack(data: data) == false {
            shouldTrack = false
            }
        }

        return shouldTrack
    }

    /// Inform all delegates that a track call has completed.
    ///
    /// - parameter forTrackProcess: TealiumRequest that was completed
    public func invokeTrackCompleted(forTrackProcess: TealiumTrackRequest) {

        for response in forTrackProcess.moduleResponses {
            let success = response.success
            let error = response.error
            let info = response.info

            multicastDelegate.invoke { $0.tealiumTrackCompleted(success: success, info: info, error: error) }
        }

    }
}
