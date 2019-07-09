//
//  TealiumLifecycleDiskStorage.swift
//  tealium-swift
//
//  Created by Craig Rouse on 05/07/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

class TealiumLifecycleDiskStorage {

    var diskStorage: TealiumDiskStorageProtocol

    public init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
    }

}
