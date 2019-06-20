//
//  TealiumAppData.swift
//  tealium-swift
//
//  Created by Jonathan Wong on 1/10/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if appdata
import TealiumCore
#endif

public class TealiumAppData: TealiumAppDataProtocol, TealiumAppDataCollection {

    private(set) var uuid: String?
    private var diskStorage: TealiumDiskStorage!
    private let bundle = Bundle.main
    private var appData = VolatileAppData()

    init(diskStorage: TealiumDiskStorage) {
        self.diskStorage = diskStorage
        setExistingAppData()
    }

    /// Public constructor to enable other modules to use TealiumAppDataCollection protocol
    public init() {
    }

    func setExistingAppData() {
        diskStorage.retrieve(as: PersistentAppData.self) { _, data, _ in
            guard let data = data else {
                self.setNewAppData()
                return
            }
            self.setLoadedAppData(data: data)
        }
    }

    /// Retrieve a copy of app data used with dispatches.
    ///
    /// - Returns: `[String: Any]`
    func getData() -> [String: Any] {
        return appData.toDictionary()
    }

    /// Deletes all app data.
    func deleteAllData() {
        appData.removeAll()
        diskStorage.delete(completion: nil)
    }

    /// Returns total items
    var count: Int {
        return appData.count
    }

    // MARK: INTERNAL
    /// Checks if persistent keys are missing from the `data` dictionary
    /// - Parameter data: The dictionary to check
    ///
    /// - TealiumAppDataKey.uuid
    /// - TealiumAppDataKey.visitorId
    ///
    /// - Returns: Bool
    class func isMissingPersistentKeys(data: [String: Any]) -> Bool {
        if data[TealiumAppDataKey.uuid] == nil { return true }
        if data[TealiumAppDataKey.visitorId] == nil { return true }
        return false
    }

    /// Converts UUID to Tealium Visitor ID format
    ///
    /// - Parameter from: String containing a UUID
    /// - Returns: String containing Tealium Visitor ID
    func visitorId(from uuid: String) -> String {
        return uuid.replacingOccurrences(of: "-", with: "")
    }

    /// Prepares new Tealium default App related data. Legacy Visitor Id data
    /// is set here as it based off app_uuid.
    ///
    /// - Parameter uuid: The uuid string to use for new persistent data.
    /// - Returns: A [String:Any] dictionary.
    func newPersistentData(for uuid: String) -> PersistentAppData {
        let vid = visitorId(from: uuid)
        let persistentData = PersistentAppData(visitorId: vid, uuid: uuid)
//        delegate?.savePersistentData(data: persistentData)
        diskStorage?.save(persistentData, completion: nil)
        return persistentData
    }

    /// Retrieves a new set of Volatile Data (usually once per app launch)
    ///
    func newVolatileData() {

        if let name = name(bundle: bundle) {
            appData.name = name
        }

        if let rdns = rdns(bundle: bundle) {
            appData.rdns = rdns
        }

        if let version = version(bundle: bundle) {
            appData.version = version
        }

        if let build = build(bundle: bundle) {
            appData.build = build
        }
    }

    /// Stores current AppData in memory
    func setNewAppData() {
        let newUuid = UUID().uuidString
        appData.persistentData = newPersistentData(for: newUuid)
        newVolatileData()
        uuid = newUuid
    }

    /// Populates in-memory AppData with existing values from persistent storage, if present
    ///
    /// - Parameter data: [String: Any] containing existing AppData variables
    func setLoadedAppData(data: PersistentAppData) {
        guard !TealiumAppData.isMissingPersistentKeys(data: data.toDictionary()) else {
            setNewAppData()
            return
        }

        appData.persistentData = data
        newVolatileData()
    }
}
