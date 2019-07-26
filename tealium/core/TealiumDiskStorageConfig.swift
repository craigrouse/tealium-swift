//
//  TealiumDiskStorageConfig.swift
//  tealium-swift
//
//  Created by Craig Rouse on 28/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public extension TealiumConfig {
    func setMinimumFreeDiskSpace(spaceInMb: Int) {
        optionalData[TealiumKey.minimumFreeDiskSpace] = spaceInMb * 1000000
    }

    func getMinimumFreeDiskSpace() -> Int {
        return optionalData[TealiumKey.minimumFreeDiskSpace] as? Int ?? TealiumValue.defaultMinimumDiskSpace
    }

    /// Enables (default) or disables disk storage
    /// If disabled, only critical data will be saved, and UserDefaults will be used in place of disk storage
    /// - parameter isEnabled: `Bool` indicating if disk storage should be enabled (default) or disabled
    func setDiskStorageEnabled(isEnabled: Bool = true) {
        self.optionalData[TealiumKey.diskStorageEnabled] = isEnabled
    }

    /// Set a net modules list to this config object.
    ///
    /// - parameter list: The TealiumModulesList to assign.
    func isDiskStorageEnabled() -> Bool {
        return self.optionalData[TealiumKey.diskStorageEnabled] as? Bool ?? true
    }

}
