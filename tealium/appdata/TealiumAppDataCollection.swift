//
//  TealiumAppDataCollection.swift
//  tealium-swift
//
//  Created by Craig Rouse on 3/14/19.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public protocol TealiumAppDataCollection {
    /// Retrieves app name from Bundle
    ///
    /// - parameter bundle: `Bundle`
    /// - returns: `String?` containing the app name
    func name(bundle: Bundle) -> String?

    /// Retrieves the rdns package identifier from Bundle
    ///
    /// - parameter bundle: `Bundle`
    /// - returns: `String?` containing the rdns package identifier
    func rdns(bundle: Bundle) -> String?

    /// Retrieves app version from Bundle
    ///
    /// - parameter bundle: `Bundle`
    /// - returns: `String?` containing the app version
    func version(bundle: Bundle) -> String?

    /// Retrieves app build number from Bundle
    ///
    /// - parameter bundle: `Bundle`
    /// - returns: `String?` containing the app build number
    func build(bundle: Bundle) -> String?
}
