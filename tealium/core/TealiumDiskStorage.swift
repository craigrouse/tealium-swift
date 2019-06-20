//
// Created by Craig Rouse on 2019-06-14.
// Copyright (c) 2019 Tealium, Inc. All rights reserved.
//

import Foundation

// TODO: Convert to protocol for easier testing
public class TealiumDiskStorage {

    static let readWriteQueue = ReadWrite("TealiumDiskStorage.label")
    let defaultDirectory = Disk.Directory.caches
    let filePrefix: String
    let module: String

    lazy var filePath: String = {
        return "\(filePrefix)\(module)/"
    }()

    /// - Parameter config: TealiumConfig
    public init(config: TealiumConfig,
                forModule module: String) {
        // The subdirectory to use for this data
        filePrefix = "\(config.account).\(config.profile)/"
        self.module = module
    }

    func fileName (_ name: String) -> String {
        return "\(self.filePath)\(name)"
    }

    func size<T: Encodable>(of data: T) -> Int? {
        return try? JSONEncoder().encode(data).count
    }

    func canWrite<T: Encodable>(data: T) -> Bool {
        guard let available = Disk.availableCapacity,
            let fileSize = size(of: data) else {
            return false
        }
        // make sure we have sufficient disk capacity (20MB)
        return available > 20000000 && fileSize < available
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
        TealiumDiskStorage.readWriteQueue.write {
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
        TealiumDiskStorage.readWriteQueue.write {
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

    public func retrieve<T: Decodable>(as type: T.Type,
                                       completion: @escaping (Bool, T?, Error?) -> Void) {
        retrieve(module, as: type, completion: completion)
    }

    public func retrieve<T: Decodable>(_ fileName: String,
                                       as type: T.Type,
                                       completion: @escaping (Bool, T?, Error?) -> Void) {
        TealiumDiskStorage.readWriteQueue.read {
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
        TealiumDiskStorage.readWriteQueue.read {
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
        do {
            try Disk.remove(fileName(module), from: defaultDirectory)
            completion?(true, nil, nil)
        } catch let error {
            completion?(false, nil, error)
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
        TealiumDiskStorage.readWriteQueue.read {
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

}
