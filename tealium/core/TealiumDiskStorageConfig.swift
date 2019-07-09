//
//  TealiumDiskStorageConfig.swift
//  tealium-swift
//
//  Created by Craig Rouse on 28/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

extension TealiumConfig {
    func setMinimumFreeDiskSpace(spaceInMb: Int) {
        optionalData[TealiumKey.minimumFreeDiskSpace] = spaceInMb * 1000000
    }

    func getMinimumFreeDiskSpace() -> Int {
        return optionalData[TealiumKey.minimumFreeDiskSpace] as? Int ?? TealiumValue.defaultMinimumDiskSpace
    }
}
