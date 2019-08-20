//
//  UserDefaults_Migration.swift
//  tealium-swift
//
//  Created by Craig Rouse on 05/08/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public class Migrator {

    var defaultsKey: String
    var filePath: String?

    private init(forModule module: String) {
        defaultsKey = "com.tealium.defaultsstorage.\(module)"
        filePath = path(filename: module)
    }

    public static func getLegacyData(forModule module: String) -> [String: Any]? {
        return Migrator(forModule: module).getLegacyData()
    }

    public static func getLegacyDataArray(forModule module: String) -> [[String: Any]]? {
        return Migrator(forModule: module).getLegacyDataArray()
    }

    public func getLegacyData() -> [String: Any]? {
        if let data = loadDataFromDefaults(forKey: defaultsKey) {
            return data
        } else if let filePath = filePath,
            let data = loadData(fromPath: filePath) {
            return data
        }

        return nil
    }

    public func getLegacyDataArray() -> [[String: Any]]? {
        if let data = UserDefaults.standard.array(forKey: defaultsKey) as? [[String: Any]] {
            return data
        }

        return nil
    }

    // MARK: Defaults Storage Migration

    func loadDataFromDefaults(forKey key: String) -> [String: Any]? {
        if let data = UserDefaults.standard.dictionary(forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
            return data
        }
        return nil
    }

    // MARK: File Storage Migration

    func fileExists(at path: String) -> Bool {

        return FileManager.default.fileExists(atPath: path)
    }

    func filename(config: TealiumConfig,
                  fileName: String) -> String {
        let prefix = "\(config.account).\(config.profile).\(config.environment)"

        return prefix.appending(".\(fileName)")
    }

    func loadData(fromPath path: String) -> [String: Any]? {

        if fileExists(at: path) {

            let data = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? [String: Any]
            try? FileManager.default.removeItem(atPath: path)
            return data

        }

        return nil
    }

    /// Gets path for filename.
    ///
    /// - Parameter filename: Filename of data file.
    /// - Returns: String if path can be created. Nil otherwise.
    func path(filename: String) -> String? {
        let parentDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let path = ".tealium/swift"
        let dirURL = URL(fileURLWithPath: path, relativeTo: parentDir[0])
        let fullPath = dirURL.path
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        } catch _ as NSError {
            // could not create directory. check permissions
            return nil
        }
        return "\(fullPath)/\(filename).data"
    }

}
