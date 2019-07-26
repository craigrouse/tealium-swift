//
//  TealiumAppDataProtocol.swift
//  tealium-swift
//
//  Created by Craig Rouse on 3/14/19.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

protocol TealiumAppDataProtocol {

    /// Add app data to all dispatches for the remainder of an active session.

    /// Retrieve a copy of app data used with dispatches.
    ///
    /// - returns: `[String: Any]`
    func getData() -> [String: Any]

    /// Stores current AppData in memory
    func setNewAppData()

    /// Populates in-memory AppData with existing values from persistent storage, if present
    ///
    /// - parameter data: `[String: Any]` containing existing AppData variables
    func setLoadedAppData(data: PersistentAppData)

    /// Deletes all app data.
    func deleteAllData()
}
