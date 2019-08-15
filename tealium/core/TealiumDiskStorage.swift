//
// Created by Craig Rouse on 2019-06-14.
// Copyright (c) 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public class TealiumDiskStorage: TealiumDiskStorageProtocol {

    static let readWriteQueue = ReadWrite("TealiumDiskStorage.label")
    let defaultDirectory = Disk.Directory.caches
    let filePrefix: String
    let module: String
    let minimumDiskSpace: Int
    var defaultsStorage: UserDefaults?
    let isCritical: Bool
    let isDiskStorageEnabled: Bool

    lazy var filePath: String = {
        return "\(filePrefix)\(module)/"
    }()

    /// - parameter config: TealiumConfig
    public init(config: TealiumConfig,
                forModule module: String,
                isCritical: Bool = false) {
        // The subdirectory to use for this data
        filePrefix = "\(config.account).\(config.profile)/"
        minimumDiskSpace = config.getMinimumFreeDiskSpace()
        self.module = module
        self.isCritical = isCritical
        self.isDiskStorageEnabled = config.isDiskStorageEnabled()
        // Provides userdefaults backing for critical data (e.g. appdata, consentmanager)
        if isCritical {
            self.defaultsStorage = UserDefaults(suiteName: filePath)
        }
    }

    func fileName (_ name: String) -> String {
        return "\(self.filePath)\(name)"
    }

    func size<T: Encodable>(of data: T) -> Int? {
        do {
            return try JSONEncoder().encode(data).count
        } catch {
            return nil
        }

    }

    public func canWrite<T: Encodable>(data: T) -> Bool {
        guard let available = Disk.availableCapacity,
            let fileSize = size(of: data) else {
            return false
        }
        // make sure we have sufficient disk capacity (20MB)
        return available > minimumDiskSpace && fileSize < available
    }

    public func canWrite() -> Bool {
        guard let available = Disk.availableCapacity else {
                return false
        }
        // make sure we have sufficient disk capacity (20MB)
        return available > minimumDiskSpace
    }

    // Configurable max size of Tealium data
    public func totalSizeSavedData() -> String? {
        if let fileUrl = try? Disk.url(for: filePrefix, in: defaultDirectory),
            let contents = try? FileManager.default.contentsOfDirectory(at: fileUrl, includingPropertiesForKeys: nil, options: []) {

            var folderSize: Int64 = 0
            contents.forEach { file in
                let fileAttributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                folderSize += fileAttributes?[FileAttributeKey.size] as? Int64 ?? 0
            }
            let fileSizeStr = ByteCountFormatter.string(fromByteCount: folderSize, countStyle: ByteCountFormatter.CountStyle.file)
            return fileSizeStr
        }
        return nil
    }

    /// Saves new data to disk, overwriting existing data.
    /// Used when a module keeps an in-memory copy of data and needs to occasionally persist the whole object to disk
    public func save(_ data: AnyCodable,
                     completion: TealiumCompletion?) {
        self.save(data, fileName: self.module, completion: completion)
    }

    /// Saves new data to disk, overwriting existing data.
    /// Used when a module keeps an in-memory copy of data and needs to occasionally persist the whole object to disk
    public func save(_ data: AnyCodable,
                     fileName: String,
                     completion: TealiumCompletion?) {
        guard isDiskStorageEnabled else {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(data) {
                self.saveToDefaults(key: self.fileName(fileName), value: data)
                completion?(true, nil, nil)
            } else {
                // TODO: Add error handling
                completion?(false, nil, nil)
            }
            return
        }

        TealiumDiskStorage.readWriteQueue.write { [unowned self] in
            do {
                try Disk.save(data, to: self.defaultDirectory, as: self.fileName(fileName))
            } catch let error {
                completion?(false, nil, error)
            }
        }
    }

    public func save<T: Encodable>(_ data: T,
                                   completion: TealiumCompletion?) {
        self.save(data, fileName: module, completion: completion)
    }

    public func save<T: Encodable>(_ data: T,
                                   fileName: String,
                                   completion: TealiumCompletion?) {
        guard isDiskStorageEnabled else {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(data) {
                self.saveToDefaults(key: self.fileName(fileName), value: data)
                completion?(true, nil, nil)
            } else {
                // TODO: Add error handling
                completion?(false, nil, nil)
            }
            return
        }

        TealiumDiskStorage.readWriteQueue.write { [unowned self] in
            do {
                guard self.canWrite(data: data) == true else {
                        // TODO: Return useful error
                        completion?(false, nil, nil)
                        return
                }
	                try Disk.save(data, to: self.defaultDirectory, as: self.fileName(fileName))
            } catch let error {
                completion?(false, nil, error)
            }
        }
    }

    public func append<T: Codable>(_ data: T,
                                   completion: TealiumCompletion?) {
        self.append(data, fileName: module, completion: completion)
    }

    public func append<T: Codable>(_ data: T,
                                   fileName: String,
                                   completion: TealiumCompletion?) {
        guard isDiskStorageEnabled else {
            // not supported if disk storage disabled
            // TODO: Add useful error
            completion?(false, nil, nil)
            return
        }
        TealiumDiskStorage.readWriteQueue.write { [unowned self] in
            do {
                guard self.canWrite(data: data) == true else {
                    // TODO: Return useful error
                    completion?(false, nil, nil)
                    return
                }
                try Disk.append(data, to: self.fileName(fileName), in: self.defaultDirectory)
            } catch let error {
                completion?(false, nil, error)
            }
        }
    }

    public func retrieve<T: Decodable>(as type: T.Type,
                                       completion: @escaping (Bool, T?, Error?) -> Void) {
        retrieve(module, as: type, completion: completion)
    }

    public func retrieve<T: Decodable>(_ fileName: String,
                                       as type: T.Type,
                                       completion: @escaping (Bool, T?, Error?) -> Void) {
        guard isDiskStorageEnabled else {
            let decoder = JSONDecoder()
            if let data = self.getFromDefaults(key: self.fileName(fileName)) as? Data,
                let decoded = try? decoder.decode(type, from: data) {
                completion(true, decoded, nil)
            } else {
                // TODO: Add error handling
                completion(false, nil, nil)
            }
            return
        }

        TealiumDiskStorage.readWriteQueue.read { [unowned self] in
            do {
                let data = try Disk.retrieve(self.fileName(fileName), from: self.defaultDirectory, as: type)
                completion(true, data, nil)
            } catch let error {
                completion(false, nil, error)
            }
        }
    }

    public func retrieve(fileName: String,
                         completion: TealiumCompletion) {
        guard isDiskStorageEnabled else {
            let decoder = JSONDecoder()
            if let data = self.getFromDefaults(key: self.fileName(fileName)) as? Data,
                let decoded = try? decoder.decode(AnyCodable.self, from: data).value as? [String: Any] {
                completion(true, decoded, nil)
            } else {
                // TODO: Add error handling
                completion(false, nil, nil)
            }
            return
        }

        TealiumDiskStorage.readWriteQueue.read { [unowned self] in
            do {
                guard let data = try Disk.retrieve(self.fileName(fileName), from: self.defaultDirectory, as: AnyCodable.self).value as? [String: Any] else {
                    // TODO: Return a useful error here
                    completion(false, nil, nil)
                    return
                }
                completion(true, data, nil)
            } catch let error {
                completion(false, nil, error)
            }
        }
    }

    public func delete(completion: TealiumCompletion?) {
        guard isDiskStorageEnabled else {
            self.removeFromDefaults(key: self.fileName(self.module))
            return
        }

        TealiumDiskStorage.readWriteQueue.write { [unowned self] in
            do {
                try Disk.remove(self.fileName(self.module), from: self.defaultDirectory)
                completion?(true, nil, nil)
            } catch let error {
                completion?(false, nil, error)
            }
        }
    }

    public func set(_ data: [String: Any],
                    //             forKey: String,
                    completion: TealiumCompletion?) {

    }

    public func append(_ data: [String: Any],
                       forKey: String,
                       fileName: String,
                       completion: TealiumCompletion?) {
        TealiumDiskStorage.readWriteQueue.read { [unowned self] in
            do {
                let data = AnyCodable(data)
                try Disk.append(data, to: self.fileName(fileName), in: self.defaultDirectory)
            } catch let error {
                completion?(false, nil, error)
            }
        }

    }

    /// Takes a key to be updated, and a new value
    /// First attempts to read from Disk. If item was a dict then decode and update the key before re-encoding and saving
    func update(key: String,
                value: Any,
                completion: TealiumCompletion?) {

    }

    /// Deletes an object for the current module, assuming the item to be removed was part of a dictionary
    func removeObject(forKey: String,
                      completion: TealiumCompletion?) {

    }

    // TODO: Add completion with result
    public func saveStringToDefaults(key: String,
                                     value: String) {
        TealiumDiskStorage.readWriteQueue.write {
            self.defaultsStorage?.set(value, forKey: key)
        }
    }

    // TODO: Add completion with result
    public func getStringFromDefaults(key: String) -> String? {
        TealiumDiskStorage.readWriteQueue.read {
            return self.defaultsStorage?.value(forKey: key) as? String
        }
        // TODO: figure out return issue - xcode 10 complaining
        return nil
    }

    // TODO: Add completion with result
    public func saveToDefaults(key: String,
                               value: Any) {
        TealiumDiskStorage.readWriteQueue.write {
            self.defaultsStorage?.set(value, forKey: key)
        }
    }

    // TODO: Add completion with result
    public func getFromDefaults(key: String) -> Any? {
        TealiumDiskStorage.readWriteQueue.read {
            return self.defaultsStorage?.value(forKey: key)
        }
        // TODO: figure out return issue - xcode 10 complaining
        return nil
    }

    // TODO: Add completion with result
    public func removeFromDefaults(key: String) {
        TealiumDiskStorage.readWriteQueue.write {
            self.defaultsStorage?.removeObject(forKey: key)
        }
    }

}
