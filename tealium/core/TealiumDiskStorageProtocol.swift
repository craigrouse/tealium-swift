//
//  TealiumDiskStorageProtocol.swift
//  tealium-swift
//
//  Created by Craig Rouse on 21/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

public protocol TealiumDiskStorageProtocol {
    func save(_ data: AnyCodable,
              completion: TealiumCompletion?)

    /// Saves new data to disk, overwriting existing data.
    /// Used when a module keeps an in-memory copy of data and needs to occasionally persist the whole object to disk
    func save(_ data: AnyCodable,
              fileName: String,
              completion: TealiumCompletion?)

    func save<T: Encodable>(_ data: T,
                            completion: TealiumCompletion?)

    func save<T: Encodable>(_ data: T,
                            fileName: String,
                            completion: TealiumCompletion?)

    func append<T: Codable>(_ data: T,
                                   completion: TealiumCompletion?)

    func append<T: Codable>(_ data: T,
                            fileName: String,
                            completion: TealiumCompletion?)

    func retrieve<T: Decodable>(as type: T.Type,
                                completion: @escaping (Bool, T?, Error?) -> Void)

    func retrieve<T: Decodable>(_ fileName: String,
                                as type: T.Type,
                                completion: @escaping (Bool, T?, Error?) -> Void)

    func retrieve(fileName: String,
                  completion: TealiumCompletion)

    func append(_ data: [String: Any],
                forKey: String,
                fileName: String,
                completion: TealiumCompletion?)

    func delete(completion: TealiumCompletion?)

    func totalSizeSavedData() -> String?

}
