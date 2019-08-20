//
//  TealiumPersistentData.swift
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

public class TealiumPersistentData {

    var persistentDataCache = PersistentDataStorage()
    let diskStorage: TealiumDiskStorageProtocol

    init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
        self.setExistingPersistentData()

    }

    func setExistingPersistentData() {
        if let data = Migrator.getLegacyData(forModule: TealiumPersistentKey.moduleName) {
            add(data: data)
        } else {
            diskStorage.retrieve(as: PersistentDataStorage.self) {_, data, _ in
                guard let data = data else {
                    return
                }
                self.persistentDataCache = data
            }
        }
    }

    /// Add additional persistent data that will be available to all track calls
    ///     for lifetime of app. Values will overwrite any pre-existing values
    ///     for a given key.
    ///
    /// - parameter data: [String:Any] of additional data to add.
    public func add(data: [String: Any]) {
        persistentDataCache.add(data: data)
        // TODO: Add logging here
        diskStorage.save(persistentDataCache, completion: nil)
    }

    /// Delete a saved value for a given key.
    ///
    /// - parameter forKeys: [String] Array of keys to remove.
    public func deleteData(forKeys: [String]) {
        var cacheCopy = persistentDataCache

        for key in forKeys {
            cacheCopy.delete(forKey: key)
        }

        persistentDataCache = cacheCopy
        // TODO: Logging
        diskStorage.save(persistentDataCache, completion: nil)
    }

    /// Delete all custom persisted data for current library instance.
    public func deleteAllData() {
        persistentDataCache = PersistentDataStorage()
        // TODO: Logging
        diskStorage.delete(completion: nil)
    }

}
