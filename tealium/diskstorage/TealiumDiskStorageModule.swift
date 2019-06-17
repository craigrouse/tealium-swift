//
// Created by Craig Rouse on 2019-06-14.
// Copyright (c) 2019 Tealium, Inc. All rights reserved.
//

import Foundation
#if diskstorage
import TealiumCore
#endif

class TealiumDiskStorageModule: TealiumModule {

    let defaultDirectory = Disk.Directory.caches
    var subDirectory = ""
    
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
        let config = request.config
        subDirectory = "/\(config.account).\(config.profile)/"
        isEnabled = true
//        filenamePrefix = TealiumFileStorageModule.filenamePrefix(config: request.config)
        didFinish(request)
    }

    func load(_ request: TealiumLoadRequest) {

        let requestingModule = request.name

//        Disk.retrieve("posts.json", from: .documents, as: [Post].self)
        guard let storedData = try? Disk.retrieve("\(subDirectory)\(requestingModule)", from: defaultDirectory, as: [String: AnyCodable].self) else {
            request.completion?(true, nil, nil)
            didFinishWithNoResponse(request)
            return
        }

        request.completion?(true, storedData as [String: Any], nil)
    }

    func save(_ request: TealiumSaveRequest) {
        let requestingModule = request.name

//        try? Disk.save(request.data.codable, to: defaultDirectory, as: requestingModule)
        try? Disk.append(request.data.codable, to: "\(subDirectory)\(requestingModule)", in: defaultDirectory)

    }

}
