//
//  TealiumConfig.swift
//  tealium-swift
//
//  Created by Jason Koo, Merritt Tidwell, Chad Hartman, Karen Tamayo, Chris Anderberg  on 8/31/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation

/// Configuration object for any Tealium instance.
open class TealiumConfig {

    public let account: String
    public let profile: String
    public let environment: String
    public let datasource: String?
    public lazy var optionalData = [String: Any]()

    /// Convenience constructor.
    ///
    /// - Parameters:
    /// - account: Tealium Account.
    /// - profile: Tealium Profile.
    /// - environment: Tealium Environment. 'prod' recommended for release.
    public convenience init(account: String,
                            profile: String,
                            environment: String) {
        self.init(account: account,
                  profile: profile,
                  environment: environment,
                  datasource: nil,
                  optionalData: nil)
    }

    /// Convenience constructor.
    ///
    /// - Parameters:
    /// - account: Tealium Account.
    /// - profile: Tealium Profile.
    /// - environment: Tealium Environment. 'prod' recommended for release.
    public convenience init(account: String,
                            profile: String,
                            environment: String,
                            datasource: String?) {
        self.init(account: account,
                  profile: profile,
                  environment: environment,
                  datasource: datasource,
                  optionalData: nil)
    }

    /// Primary constructor.
    ///
    /// - Parameters:
    /// - account: Tealium account name string to use.
    /// - profile: Tealium profile string.
    /// - environment: Tealium environment string.
    /// - optionalData: Optional [String:Any] dictionary meant primarily for module use.
    public init(account: String,
                profile: String,
                environment: String,
                datasource: String?,
                optionalData: [String: Any]?) {
        self.account = account
        self.environment = environment
        self.profile = profile
        self.datasource = datasource
        if let optionalData = optionalData {
            self.optionalData = optionalData
        }
    }

}

extension TealiumConfig: Equatable {

    public static func == (lhs: TealiumConfig, rhs: TealiumConfig ) -> Bool {
        if lhs.account != rhs.account { return false }
        if lhs.profile != rhs.profile { return false }
        if lhs.environment != rhs.environment { return false }
        let lhsKeys = lhs.optionalData.keys.sorted()
        let rhsKeys = rhs.optionalData.keys.sorted()
        if lhsKeys.count != rhsKeys.count { return false }
        for (index, key) in lhsKeys.enumerated() {
            if key != rhsKeys[index] { return false }
            let lhsValue = String(describing: lhs.optionalData[key])
            let rhsValue = String(describing: rhs.optionalData[key])
            if lhsValue != rhsValue { return false }
        }

        return true
    }

}

enum TealiumConfigKey {
    static let queue = "com.tealium.queue"
}

// MARK: - Future support for alternate queue assignments for library module processing.
extension TealiumConfig {

    public func dispatchQueue() -> DispatchQueue {
        guard let queue = self.optionalData[TealiumConfigKey.queue] as? DispatchQueue else {
            let defaultQueue = TealiumConfig.defaultDispatchQueue()
            self.setDispatchQueue(defaultQueue)
            return defaultQueue
        }
        return queue

    }

    public func setDispatchQueue(_ queue: DispatchQueue ) {
        self.optionalData[TealiumConfigKey.queue] = queue
    }

    static func defaultDispatchQueue() -> DispatchQueue {
        return DispatchQueue.main
    }
}

public extension TealiumConfig {
    /// Get the existing modules list assigned to this config object.
    ///
    /// - returns: TealiumModulesList as an optional.
    func getModulesList() -> TealiumModulesList? {
        guard let list = self.optionalData[TealiumModulesListKey.config] as? TealiumModulesList else {
            return nil
        }

        return list
    }

    /// Set a net modules list to this config object.
    ///
    /// - parameter list: The TealiumModulesList to assign.
    func setModulesList(_ list: TealiumModulesList ) {
        self.optionalData[TealiumModulesListKey.config] = list
    }
}