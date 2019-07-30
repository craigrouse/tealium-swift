//
//  TealiumLifecycleModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 1/10/17.
//  Copyright © 2017 Tealium, Inc. All rights reserved.
//
//

import Foundation

#if TEST
#else
#if os(OSX)
#else
import UIKit
#endif
#endif

#if lifecycle
import TealiumCore
#endif

// MARK: ENUMS
// swiftlint:disable file_length
// swiftlint:disable line_length
enum TealiumLifecycleModuleKey {
    static let moduleName = "lifecycle"
    static let queueName = "com.tealium.lifecycle"
}

enum TealiumLifecycleModuleError: Error {
    case unableToSaveToDisk
}

// MARK: 
// MARK: EXTENSIONS

public extension Tealium {

    func lifecycle() -> TealiumLifecycleModule? {
        guard let module = modulesManager.getModule(forName: TealiumLifecycleModuleKey.moduleName) as? TealiumLifecycleModule else {
            return nil
        }

        return module
    }

}

// MARK: 
// MARK: MODULE SUBCLASS

public class TealiumLifecycleModule: TealiumModule {

    var areListenersActive = false
    var enabledPrior = false    // To differentiate between new launches and re-enables.
    var lifecycle: TealiumLifecycle?
    var uniqueId: String = ""
    var lastProcess: TealiumLifecycleType?
//    lazy var dispatchQueue: DispatchQueue? = {
//        return DispatchQueue(label: TealiumLifecycleModuleKey.moduleName)
//    }()
    var lifecyclePersistentData: TealiumLifecyclePersistentData!

    // MARK: TEALIUM MODULE CONFIG
    override public class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumLifecycleModuleKey.moduleName,
                                   priority: 175,
                                   build: 3,
                                   enabled: true)
    }

    override public func enable(_ request: TealiumEnableRequest) {
        self.lifecyclePersistentData = TealiumLifecyclePersistentData(diskStorage: TealiumDiskStorage(config: request.config, forModule: TealiumLifecycleModuleKey.moduleName))
        if areListenersActive == false {
            addListeners()

            delegate?.tealiumModuleRequests(module: self,
                                            process: TealiumReportNotificationsRequest())
        }

        let config = request.config
        uniqueId = "\(config.account).\(config.profile).\(config.environment)"
        lifecycle = savedOrNewLifeycle(uniqueId: uniqueId)
//        let save = lifecyclePersistentData.save(lifecycle!, usingUniqueId: uniqueId)
//
//        if save.success == false {
//            self.didFailToFinish(request,
//                                 error: save.error!)
//            return
//        }

        isEnabled = true

        didFinish(request)
    }

    override public func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        lifecycle = nil
//        dispatchQueue = nil
        didFinish(request)
    }

    override public func handleReport(_ request: TealiumRequest) {
        if isEnabled == false {
            return
        }

        if request as? TealiumEnableRequest != nil {

            launchDetected()
        }

        // NOTE: This type of check will fail.
        //        if request is TealiumEnableRequest {
        //        }
    }

    override public func track(_ track: TealiumTrackRequest) {

        guard isEnabled == true else {
            didFinishWithNoResponse(track)
            return
        }

        // do not add data to queued hits
        guard track.trackDictionary[TealiumKey.wasQueued] as? String == nil else {
            didFinishWithNoResponse(track)
            return
        }

        // Lifecycle ready?
        guard var lifecycle = lifecycle else {
            didFinish(track)
            return
        }

        var newData = lifecycle.newTrack(atDate: Date())
        newData += track.trackDictionary
        let newTrack = TealiumTrackRequest(data: newData,
                                           completion: track.completion)
        didFinish(newTrack)
    }

    // MARK: 
    // MARK: PUBLIC

    public func launchDetected() {
        processDetected(type: .launch)
    }

    @objc
    public func sleepDetected() {
        processDetected(type: .sleep)
    }

    @objc
    public func wakeDetected() {
        processDetected(type: .wake)
    }

    // MARK: 
    // MARK: INTERNAL

    func addListeners() {
        #if TEST
        #else
        #if os(watchOS)
        #else
        #if os(OSX)
        #else
        // swiftlint:disable identifier_name
        #if swift(>=4.2)
        let notificationNameApplicationDidBecomeActive = UIApplication.didBecomeActiveNotification
        let notificationNameApplicationWillResignActive = UIApplication.willResignActiveNotification
        #else
        let notificationNameApplicationDidBecomeActive = NSNotification.Name.UIApplicationDidBecomeActive
        let notificationNameApplicationWillResignActive = NSNotification.Name.UIApplicationWillResignActive
        #endif
        // swiftlint:enable identifier_name
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(wakeDetected),
                                               name: notificationNameApplicationDidBecomeActive,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sleepDetected),
                                               name: notificationNameApplicationWillResignActive,
                                               object: nil)

        #endif
        #endif
        #endif
        areListenersActive = true
    }

    func processDetected(type: TealiumLifecycleType) {
        if processAcceptable(type: type) == false {
            return
        }

        lastProcess = type
//        dispatchQueue?.async {
            self.process(type: type)
//        }
    }

    func process(type: TealiumLifecycleType) {
        // If lifecycle has been nil'd out - module not ready or has been disabled
        guard var lifecycle = self.lifecycle else { return }

        // Setup data to be used in switch statement
        let date = Date()
        var data: [String: Any]

        // Update internal model and retrieve data for a track call
        switch type {
        case .launch:
            if enabledPrior == true { return }
            enabledPrior = true
            data = lifecycle.newLaunch(atDate: date,
                                       overrideSession: nil)
        case .sleep:
            data = lifecycle.newSleep(atDate: date)
        case .wake:
            data = lifecycle.newWake(atDate: date,
                                     overrideSession: nil)
        }
        self.lifecycle = lifecycle
        // Save now in case we crash later
        save()

        // Make the track request to the modulesManager
        requestTrack(data: data)
    }

    /// Prevent manual spanning of repeated lifecycle calls to system.
    ///
    /// - Parameters:
    ///   - type: Lifecycle event type
    ///   - lastProcess: Last lifecycle event type recorded
    /// - returns: Bool is process should be allowed to continue
    func processAcceptable(type: TealiumLifecycleType) -> Bool {
        switch type {
        case .launch:
            // Can only occur once per app lifecycle
            if enabledPrior == true {
                return false
            }
            if lastProcess != nil {
                // Should never have more than 1 launch event per app lifecycle run
                return false
            }
        case .sleep:
            guard let lastProcess = lastProcess else {
                // Should not be possible
                return false
            }
            if lastProcess != .wake && lastProcess != .launch {
                return false
            }
        case .wake:
            guard let lastProcess = lastProcess else {
                // Should not be possible
                return false
            }
            if lastProcess != .sleep {
                return false
            }
        }
        return true
    }

    func requestTrack(data: [String: Any]) {
        guard let title = data[TealiumLifecycleKey.type] as? String else {
            // Should not happen
            return
        }

        // Conforming to universally available Tealium data variables
        let trackData = Tealium.trackDataFor(title: title,
                                             optionalData: data)
        let track = TealiumTrackRequest(data: trackData,
                                        completion: nil)
        self.delegate?.tealiumModuleRequests(module: self,
                                             process: track)
    }

    func save() {
        // Error handling?
        guard let lifecycle = self.lifecycle else {
            return
        }
        _ = lifecyclePersistentData.save(lifecycle, usingUniqueId: uniqueId)
    }

    func savedOrNewLifeycle(uniqueId: String) -> TealiumLifecycle {
        // Attempt to load first
        if let loadedLifecycle = lifecyclePersistentData.load() {
            return loadedLifecycle
        }
        return TealiumLifecycle()
    }

    deinit {
        if areListenersActive == true {
            #if os(OSX)
            #else
            NotificationCenter.default.removeObserver(self)
            #endif
        }
    }

}

// MARK: 
// MARK: LIFECYCLE

enum TealiumLifecycleKey {
    static let autotracked = "autotracked"
    static let dayOfWeek = "lifecycle_dayofweek_local"
    static let daysSinceFirstLaunch = "lifecycle_dayssincelaunch"
    static let daysSinceLastUpdate = "lifecycle_dayssinceupdate"
    static let daysSinceLastWake = "lifecycle_dayssincelastwake"
    static let didDetectCrash = "lifecycle_diddetectcrash"
    static let firstLaunchDate = "lifecycle_firstlaunchdate"
    static let firstLaunchDateMMDDYYYY = "lifecycle_firstlaunchdate_MMDDYYYY"
    static let hourOfDayLocal = "lifecycle_hourofday_local"
    static let isFirstLaunch = "lifecycle_isfirstlaunch"
    static let isFirstLaunchUpdate = "lifecycle_isfirstlaunchupdate"
    static let isFirstWakeThisMonth = "lifecycle_isfirstwakemonth"
    static let isFirstWakeToday = "lifecycle_isfirstwaketoday"
    static let lastLaunchDate = "lifecycle_lastlaunchdate"
    static let lastSleepDate = "lifecycle_lastsleepdate"
    static let lastWakeDate = "lifecycle_lastwakedate"
    static let lastUpdateDate = "lifecycle_lastupdatedate"
    static let launchCount = "lifecycle_launchcount"
    static let priorSecondsAwake = "lifecycle_priorsecondsawake"
    static let secondsAwake = "lifecycle_secondsawake"
    static let sleepCount = "lifecycle_sleepcount"
    static let type = "lifecycle_type"
    static let totalCrashCount = "lifecycle_totalcrashcount"
    static let totalLaunchCount = "lifecycle_totallaunchcount"
    static let totalWakeCount = "lifecycle_totalwakecount"
    static let totalSleepCount = "lifecycle_totalsleepcount"
    static let totalSecondsAwake = "lifecycle_totalsecondsawake"
    static let updateLaunchDate = "lifecycle_updatelaunchdate"
    static let wakeCount = "lifecycle_wakecount"
}

enum TealiumLifecycleCodingKey {
    static let sessionFirst = "first"
    static let sessions = "sessions"
    static let sessionsSize = "session_size"
    static let totalSecondsAwake = "totalSecondsAwake"
}

public enum TealiumLifecycleType {
    case launch, sleep, wake

    var description: String {
        switch self {
        case .launch:
            return "launch"
        case .sleep:
            return "sleep"
        case .wake:
            return "wake"
        }
    }
}

enum TealiumLifecycleValue {
    static let yes = "true"
}

public func == (lhs: TealiumLifecycle, rhs: TealiumLifecycle ) -> Bool {
    if lhs.countCrashTotal != rhs.countCrashTotal { return false }
    if lhs.countLaunchTotal != rhs.countLaunchTotal { return false }
    if lhs.countSleepTotal != rhs.countSleepTotal { return false }
    if lhs.countWakeTotal != rhs.countWakeTotal { return false }

    return true
}

extension Array where Element == TealiumLifecycleSession {

    /// Get item before last
    ///
    /// - returns: Target item or item at index 0 if only 1 item.
    func beforeLast() -> Element? {
        if self.isEmpty {
            return nil
        }

        var index = self.count - 2
        if index < 0 {
            index = 0
        }
        return self[index]
    }

}

// swiftlint:enable line_length
// swiftlint:enable type_body_length
// swiftlint:enable file_length
