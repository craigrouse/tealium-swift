//
//  TealiumAppDataModuleExtensions.swift
//  tealium-swift
//
//  Created by Craig Rouse on 14/03/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation
#if appdata
import TealiumCore
#endif

extension TealiumAppDataModule: TealiumSaveDelegate {

    func savePersistentData(data: Any) {
        guard let data = data as? PersistentAppData else {
            return
        }
        self.diskStorage.save(data, fileName: "PersistentAppData", completion: nil)
        //        Disk.save(data, to: .caches, as: "test")
    }

    /// Initiates a save request to store persistent data
    ///
    /// - Parameter data: [String: Any] of data to be stored
    func savePersistentData(data: [String: Any]) {
        let saveRequest = TealiumSaveRequest(name: TealiumAppDataModule.moduleConfig().name,
                                             data: data)

        delegate?.tealiumModuleRequests(module: self,
                                        process: saveRequest)
    }
}
