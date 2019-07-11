//
//  TealiumPersistentDataConfig.swift
//  ios
//
//  Created by Craig Rouse on 11/07/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

#if defaultsstorage
import TealiumCore
#elseif diskstorage
import TealiumCore
#endif

import Foundation

// MARK: 
// MARK: EXTENSIONS
public extension Tealium {

    /// Get the Data Manager instance for accessing file persistence and auto data variable APIs.
    /// - Returns: Optional TealiumPersistentData instance (nil if disabled)
    func persistentData() -> TealiumPersistentData? {
        guard let module = modulesManager.getModule(forName: TealiumPersistentKey.moduleName) as? TealiumPersistentDataModule else {
            return nil
        }

        return module.persistentData
    }

}
