//
//  TealiumAttributionDataProtocol.swift
//  tealium-swift
//
//  Created by Craig Rouse on 14/03/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public protocol TealiumAttributionDataProtocol {

    /// - returns: `[String: Any]` containing all attribution data
    var allAttributionData: [String: Any] { get }

    /// - returns: `PersistentAttributionData` containing all Apple Search Ads info, if available
    var appleAttributionDetails: `PersistentAttributionData`? { get set }

    /// - returns: `String` representation of IDFA
    var idfa: String { get }

    /// - returns: `String` representation of IDFV
    var idfv: String { get }

    /// - returns: `[String: Any]` of all volatile data (collected at init time): IDFV, IDFA, isTrackingAllowed
    var volatileData: [String: Any] { get }

    /// - returns: `String` representation of Limit Ad Tracking setting (true if tracking allowed, false if disabled)
    var isAdvertisingTrackingEnabled: String { get }

    /// Requests Apple Search Ads data from AdClient API
    /// - parameter completion: Completion block to be executed asynchronously when Search Ads data is returned
    func appleSearchAdsData(_ completion: @escaping (PersistentAttributionData) -> Void)
}
