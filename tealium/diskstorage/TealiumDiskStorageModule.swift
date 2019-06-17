//
// Created by Craig Rouse on 2019-06-14.
// Copyright (c) 2019 Tealium, Inc. All rights reserved.
//

import Foundation
import TealiumCore

class TealiumDiskStorageModule: TealiumModule {

    let defaultDirectory = Disk.Directory.documents

    override class func moduleConfig() -> TealiumModuleConfig {
        return  TealiumModuleConfig(name: TealiumDiskStorageConstants.moduleName.rawValue,
                                    priority: 350,
                                    build: 1,
                                    enabled: true)
    }

    override func handle(_ request: TealiumRequest) {

        if let request = request as? TealiumEnableRequest {
            enable(request)
        } else if let request = request as? TealiumDisableRequest {
            disable(request)
        } else if let request = request as? TealiumLoadRequest {
            load(request)
        } else if let request = request as? TealiumSaveRequest {
            save(request)
        } else if let request = request as? TealiumDeleteRequest {
//            delete(request)
        } else {
            didFinishWithNoResponse(request)
        }
    }

    override func enable(_ request: TealiumEnableRequest) {

        isEnabled = true
//        filenamePrefix = TealiumFileStorageModule.filenamePrefix(config: request.config)
        didFinish(request)
    }

    func load(_ request: TealiumLoadRequest) {

        let requestingModule = request.name

//        Disk.retrieve("posts.json", from: .documents, as: [Post].self)
        guard let storedData = try? Disk.retrieve(requestingModule, from: defaultDirectory, as: [String: AnyCodable].self) else {
            request.completion?(true, nil, nil)
            didFinishWithNoResponse(request)
            return
        }

        request.completion?(true, storedData as [String: Any], nil)
    }

    func save(_ request: TealiumSaveRequest) {
        let requestingModule = request.name

//        try? Disk.save(request.data.codable, to: defaultDirectory, as: requestingModule)
        try? Disk.append(request.data.codable, to: requestingModule, in: defaultDirectory)

    }

}
