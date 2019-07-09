//
//  PersistentAppData.swift
//  tealium-swift
//
//  Created by Craig Rouse on 20/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public struct PersistentAppData: Codable {
    public let visitorId: String
    public let uuid: String
    public func toDictionary() -> [String: Any] {
        return [TealiumKey.uuid: uuid,
                TealiumKey.visitorId: visitorId]
    }
}
