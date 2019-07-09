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

// TODO: Unarchiving legacy lifecycle causes a crash
open class TealiumLifecyclePersistentData {

    let diskStorage: TealiumDiskStorageProtocol

    init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
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
//        diskStorage.save(lifecycle as Encodable) { success, error in
//            return (success, error)
//        }
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
