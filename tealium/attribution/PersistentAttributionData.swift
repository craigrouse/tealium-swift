//
//  PersistentAttributionData.swift
//  tealium-swift
//
//  Created by Craig Rouse on 09/07/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public struct PersistentAttributionData: Codable {

    var clickedWithin30D: String?,
        clickedDate: String?,
        conversionDate: String?,
        orgName: String?,
        campaignId: String?,
        campaignName: String?,
        adGroupId: String?,
        adGroupName: String?,
        adKeyword: String?

    /// returns: `[String: Any]`
    public func toDictionary() -> [String: Any] {
        var appleAttributionDetails = [String: Any]()
        if let clickedWithin30D = clickedWithin30D {
            appleAttributionDetails[TealiumAttributionKey.clickedWithin30D] = clickedWithin30D
        }
        if let clickedDate = clickedDate {
            appleAttributionDetails[TealiumAttributionKey.clickedDate] = clickedDate
        }
        if let conversionDate = conversionDate {
            appleAttributionDetails[TealiumAttributionKey.conversionDate] = conversionDate
        }
        if let orgName = orgName {
            appleAttributionDetails[TealiumAttributionKey.orgName] = orgName
        }
        if let campaignId = campaignId {
            appleAttributionDetails[TealiumAttributionKey.campaignId] = campaignId
        }
        if let campaignName = campaignName {
            appleAttributionDetails[TealiumAttributionKey.campaignName] = campaignName
        }
        if let adGroupId = adGroupId {
            appleAttributionDetails[TealiumAttributionKey.adGroupId] = adGroupId
        }
        if let adGroupName = adGroupName {
            appleAttributionDetails[TealiumAttributionKey.adGroupName] = adGroupName
        }
        if let adKeyword = adKeyword {
            appleAttributionDetails[TealiumAttributionKey.adKeyword] = adKeyword
        }
        return appleAttributionDetails
    }
}
