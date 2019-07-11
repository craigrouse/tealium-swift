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

//// MARK:
//// MARK: PERSISTENT DATA
//
//protocol TealiumPersistentDataDelegate: class {
//    func requestSave(data: [String: Any])
//    func requestLoad(completion: @escaping TealiumCompletion)
//}

public struct PersistentDataStorage: Codable {
    var data: AnyCodable
    lazy var isEmpty: Bool = {
        guard let totalValues = (self.data.value as? [String: Any])?.count else {
            return true
        }
        return !(totalValues > 0)
    }()

    public init() {
        self.data = [String: Any]().codable
    }

    public func values() -> [String: Any]? {
        return self.data.value as? [String: Any]
    }

    public mutating func add(data: [String: Any]) {
        var newData = [String: Any]()

        if let existingData = self.data.value as? [String: Any] {
            newData += existingData
        }

        newData += data
        self.data = newData.codable
    }

    public mutating func delete(forKey key: String) {
        guard var data = self.data.value as? [String: Any] else {
            return
        }

        data[key] = nil

        self.data = data.codable
    }

}

public class TealiumPersistentData {

//    var persistentDataCache = [String: Any]()
    var persistentDataCache = PersistentDataStorage()
    let diskStorage: TealiumDiskStorageProtocol

    init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
        self.setExistingPersistentData()

    }

    func setExistingPersistentData() {
        diskStorage.retrieve(as: PersistentDataStorage.self) {_, data, _ in

            guard let data = data else {
                return
            }
            self.persistentDataCache = data
        }
    }

    /// Add additional persistent data that will be available to all track calls
    ///     for lifetime of app. Values will overwrite any pre-existing values
    ///     for a given key.
    ///
    /// - Parameter data: [String:Any] of additional data to add.
    public func add(data: [String: Any]) {
        persistentDataCache.add(data: data)
        // TODO: Add logging here
        diskStorage.save(persistentDataCache, completion: nil)
    }

    /// Delete a saved value for a given key.
    ///
    /// - Parameter forKeys: [String] Array of keys to remove.
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
