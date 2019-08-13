//
//  TealiumConsentPreferencesStorage.swift
//  tealium-swift
//
//  Created by Craig Rouse on 4/26/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if consentmanager
import TealiumCore
#endif

/// Dedicated persistent storage for consent preferences
class TealiumConsentPreferencesStorage {

    static let consentStorage = UserDefaults.standard
    static let key = "consentpreferences"
    let readWriteQueue = ReadWrite("\(TealiumConsentPreferencesStorage.key).label")
    let diskStorage: TealiumDiskStorageProtocol

    public init(diskStorage: TealiumDiskStorageProtocol) {
        self.diskStorage = diskStorage
        if let preferences = retrieveConsentPreferencesFromUserDefaults() {
            self.persist(preferences)
        }
    }

    /// Saves the consent preferences to persistent storage
    ///
    /// - parameter prefs: [String: Any] containing the current consent preferences
    func storeConsentPreferences(_ prefs: TealiumConsentUserPreferences) {
        persist(prefs)
    }

    /// Gets the saved consent preferences from persistent storage
    ///
    /// - returns: [String: Any]? containing the saved consent preferences. Nil if empty.
    func retrieveConsentPreferences() -> TealiumConsentUserPreferences? {
        return read()
    }

    // one-time migration from userdefaults
    func retrieveConsentPreferencesFromUserDefaults() -> TealiumConsentUserPreferences? {
        var consentPreferences: TealiumConsentUserPreferences?
        if let data = UserDefaults.standard.dictionary(forKey: TealiumConsentPreferencesStorage.key) {
            var temp = TealiumConsentUserPreferences(consentStatus: nil, consentCategories: nil)
            temp.initWithDictionary(preferencesDictionary: data)
            consentPreferences = temp
            UserDefaults.standard.removeObject(forKey: TealiumConsentPreferencesStorage.key)
        }
        return consentPreferences
    }

    /// Deletes all previously saved consent preferences from persistent storage
    func clearStoredPreferences() {
        diskStorage.delete(completion: nil)
    }

    /// Saves the consent preferences to persistent storage
    ///
    /// - parameter dict: [String: Any] containing the current consent preferences
    private func persist(_ dict: TealiumConsentUserPreferences) {
        // TODO: do something with completion
        diskStorage.save(dict, completion: nil)
    }

    /// Gets the saved consent preferences from persistent storage
    ///
    /// - returns: [String: Any]? containing the saved consent preferences. Nil if empty.
    private func read() -> TealiumConsentUserPreferences? {
        var consentPreferences: TealiumConsentUserPreferences?
        readWriteQueue.read {
            diskStorage.retrieve(as: TealiumConsentUserPreferences.self) { _, data, error in
                guard error == nil else {
                    consentPreferences = nil
                    return
                }
                consentPreferences = data
            }
        }
        return consentPreferences
    }
}
