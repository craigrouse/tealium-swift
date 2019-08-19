//
//  TealiumLifecyclePersistentData.swift
//  tealium-swift
//
//  Created by Jason Koo on 11/17/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation

enum TealiumLifecyclePersistentDataError: Error {
    case couldNotArchiveAsData
    case couldNotUnarchiveData
    case archivedDataMismatchWithOriginalData
}

open class TealiumLifecyclePersistentData {

    let diskStorage: TealiumDiskStorageProtocol

    init(diskStorage: TealiumDiskStorageProtocol,
         uniqueId: String? = nil) {
        self.diskStorage = diskStorage
        // one-time migration
        if let uniqueId = uniqueId, let lifecycle = retrieveLegacyLifecycleData(uniqueId: uniqueId) {
            _ = self.save(lifecycle, usingUniqueId: uniqueId)
        }
    }

    func retrieveLegacyLifecycleData(uniqueId: String) -> TealiumLifecycle? {
        guard let data = UserDefaults.standard.object(forKey: uniqueId) as? Data else {
            // No saved data
            return nil
        }

        do {
            // TODO: Check namespacing for Carthage and CocoaPods - probably need TealiumLifecycle.TealiumLifeycle for Carthage
            NSKeyedUnarchiver.setClass(TealiumLifecycleLegacyData.self, forClassName: "Tealium.TealiumLifecycle")
            NSKeyedUnarchiver.setClass(TealiumLifecycleLegacySession.self, forClassName: "Tealium.TealiumLifecycleSession")
            guard let lifecycle = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? TealiumLifecycleLegacyData else {
                return nil
            }
            let encoder = JSONEncoder()
            guard let encoded = try? encoder.encode(lifecycle) else {
                return nil
            }
            let decoder = JSONDecoder()
            guard let decoded = try? decoder.decode(TealiumLifecycle.self, from: encoded) else {
                return nil
            }
            UserDefaults.standard.removeObject(forKey: uniqueId)
            return decoded
        } catch {
            // invalidArchiveOperationException
            return nil
        }
    }

    class func dataExists(forUniqueId: String) -> Bool {
        guard UserDefaults.standard.object(forKey: forUniqueId) as? Data != nil else {
            return false
        }

        return true
    }

     func load() -> TealiumLifecycle? {
        var lifecycle: TealiumLifecycle?
        diskStorage.retrieve(as: TealiumLifecycle.self) { _, data, _ in
            lifecycle = data
        }
        return lifecycle
    }

    func save(_ lifecycle: TealiumLifecycle, usingUniqueId: String) -> (success: Bool, error: Error?) {
        diskStorage.save(lifecycle, completion: nil)
        return (true, nil)
    }

    class func deleteAllData(forUniqueId: String) -> Bool {
        // False option not yet implemented
        if dataExists(forUniqueId: forUniqueId) == false {
            return true
        }

        UserDefaults.standard.removeObject(forKey: forUniqueId)

        if UserDefaults.standard.object(forKey: forUniqueId) == nil {
            return true
        }

        return false
    }

}
