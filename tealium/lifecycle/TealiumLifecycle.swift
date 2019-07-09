//
//  TealiumLifecycle.swift
//  tealium-swift
//
//  Created by Craig Rouse on 05/07/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

// swiftlint:disable type_body_length
public struct TealiumLifecycle: Codable {

    var autotracked: String?

    // Counts being tracked as properties instead of processing through
    //  sessions data every time. Also, not all sessions records will be kept
    //  to prevent memory bloat.
    var countLaunch: Int
    var countSleep: Int
    var countWake: Int
    var countCrashTotal: Int
    var countLaunchTotal: Int
    var countSleepTotal: Int
    var countWakeTotal: Int
    var dateLastUpdate: Date?
    var totalSecondsAwake: Int
    var sessionsSize: Int
    var sessions = [TealiumLifecycleSession]() {
        didSet {
            // Limit size of sessions records
            if sessions.count > sessionsSize &&
                sessionsSize > 1 {
                sessions.remove(at: 1)
            }
        }
    }

    /// Constructor. Should only be called at first init after install.
    ///
    /// - Parameter date: Date that the object should be created for.
    init() {
        countLaunch = 0
        countWake = 0
        countSleep = 0
        countCrashTotal = 0
        countLaunchTotal = 0
        countWakeTotal = 0
        countSleepTotal = 0
        sessionsSize = 100     // Need a wide berth to capture wakes, sleeps, and updates
        totalSecondsAwake = 0
    }

    // MARK: 
    // MARK: PERSISTENCE SUPPORT
    public init?(coder: NSCoder) {
        countLaunch = coder.decodeInteger(forKey: TealiumLifecycleKey.launchCount)
        countSleep = coder.decodeInteger(forKey: TealiumLifecycleKey.sleepCount)
        countWake = coder.decodeInteger(forKey: TealiumLifecycleKey.wakeCount)
        countCrashTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalCrashCount)
        countLaunchTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalLaunchCount)
        countSleepTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalSleepCount)
        countWakeTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalWakeCount)
        dateLastUpdate = coder.decodeObject(forKey: TealiumLifecycleKey.lastUpdateDate) as? Date
        if let savedSessions = coder.decodeObject(forKey: TealiumLifecycleCodingKey.sessions) as? [TealiumLifecycleSession] {
            sessions = savedSessions
        }
        sessionsSize = coder.decodeInteger(forKey: TealiumLifecycleCodingKey.sessionsSize)
        totalSecondsAwake = coder.decodeInteger(forKey: TealiumLifecycleCodingKey.totalSecondsAwake)
    }

    public func encode(with coder: NSCoder) {
        coder.encode(self.countLaunch, forKey: TealiumLifecycleKey.launchCount)
        coder.encode(self.countSleep, forKey: TealiumLifecycleKey.sleepCount)
        coder.encode(self.countWake, forKey: TealiumLifecycleKey.wakeCount)
        coder.encode(self.countCrashTotal, forKey: TealiumLifecycleKey.totalCrashCount)
        coder.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalLaunchCount)
        coder.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalSleepCount)
        coder.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalWakeCount)
        coder.encode(self.dateLastUpdate, forKey: TealiumLifecycleKey.lastUpdateDate)
        coder.encode(self.sessions, forKey: TealiumLifecycleCodingKey.sessions)
        coder.encode(self.sessionsSize)
        coder.encode(self.totalSecondsAwake, forKey: TealiumLifecycleCodingKey.totalSecondsAwake)
    }

    // MARK: 
    // MARK: PUBLIC

    /// Trigger a new launch and return data for it.
    ///
    /// - Parameters:
    ///   - atDate: Date to trigger launch from.
    ///   - overrideSession: Optional override session. For testing main use case.
    /// - Returns: Dictionary of variables in a [String:Any] object
    public mutating func newLaunch(atDate: Date,
                                   overrideSession: TealiumLifecycleSession?) -> [String: Any] {
        autotracked = TealiumLifecycleValue.yes
        countLaunch += 1
        countLaunchTotal += 1
        countWake += 1
        countWakeTotal += 1

        let newSession = (overrideSession != nil) ? overrideSession! : TealiumLifecycleSession(withLaunchDate: atDate)
        sessions.append(newSession)

        if newCrashDetected() == TealiumLifecycleValue.yes {
            countCrashTotal += 1
        }
        if isFirstLaunchAfterUpdate() == TealiumLifecycleValue.yes {
            resetCountsForNewVersion(forDate: atDate)
        }

        return self.asDictionary(type: TealiumLifecycleType.launch.description,
                                 forDate: atDate)
    }

    /// Trigger a new wake and return data for it.
    ///
    /// - Parameters:
    ///   - atDate: Date to trigger wake from.
    ///   - overrideSession: Optional override session.
    /// - Returns: Dictionary of variables in a [String:Any] object
    public mutating func newWake(atDate: Date, overrideSession: TealiumLifecycleSession?) -> [String: Any] {
        autotracked = TealiumLifecycleValue.yes
        countWake += 1
        countWakeTotal += 1

        let newSession = (overrideSession != nil) ? overrideSession! : TealiumLifecycleSession(withWakeDate: atDate)
        sessions.append(newSession)

        return self.asDictionary(type: TealiumLifecycleType.wake.description,
                                 forDate: atDate)
    }

    /// Trigger a new sleep and return data for it.
    ///
    /// - Parameter atDate: Date to set sleep to.
    /// - Returns: Dictionary of variables in a [String:Any] object
    public mutating func newSleep(atDate: Date) -> [String: Any] {
        autotracked = TealiumLifecycleValue.yes
        countSleep += 1
        countSleepTotal += 1

        guard var currentSession = sessions.last else {
            // Sleep call somehow made prior to the first launch event
            return [:]
        }

        currentSession.sleepDate = atDate
        self.totalSecondsAwake += currentSession.secondsElapsed
        sessions.removeLast()
        sessions.append(currentSession)
        return self.asDictionary(type: TealiumLifecycleType.sleep.description,
                                 forDate: atDate)
    }

    public mutating func newTrack(atDate: Date) -> [String: Any] {
        guard sessions.last != nil else {
            // Track request before launch processed
            return [:]
        }

        autotracked = nil
        return self.asDictionary(type: nil,
                                 forDate: atDate)
    }

    // MARK: 
    // MARK: INTERNAL RESETS
    mutating func resetCountsForNewVersion(forDate: Date) {
        countWake = 1
        countLaunch = 1
        countSleep = 0
        dateLastUpdate = forDate
    }

    // MARK: 
    // MARK: INTERNAL HELPERS

    func asDictionary(type: String?,
                      forDate: Date) -> [String: Any] {
        var dict = [String: Any]()

        let firstSession = sessions.first

        dict[TealiumLifecycleKey.autotracked] = self.autotracked
        if type == TealiumLifecycleType.launch.description {
            dict[TealiumLifecycleKey.didDetectCrash] = newCrashDetected()
        }
        dict[TealiumLifecycleKey.dayOfWeek] = dayOfWeekLocal(forDate: forDate)
        dict[TealiumLifecycleKey.daysSinceFirstLaunch] = daysFrom(earlierDate: firstSession?.wakeDate, laterDate: forDate)
        dict[TealiumLifecycleKey.daysSinceLastUpdate] = daysFrom(earlierDate: dateLastUpdate, laterDate: forDate)
        dict[TealiumLifecycleKey.daysSinceLastWake] = daysSinceLastWake(type: type, toDate: forDate)
        dict[TealiumLifecycleKey.firstLaunchDate] = firstSession?.wakeDate?.iso8601String
        dict[TealiumLifecycleKey.firstLaunchDateMMDDYYYY] = firstSession?.wakeDate?.mmDDYYYYString
        dict[TealiumLifecycleKey.hourOfDayLocal] = hourOfDayLocal(forDate: forDate)
        dict[TealiumLifecycleKey.isFirstLaunch] = isFirstLaunch()
        dict[TealiumLifecycleKey.isFirstLaunchUpdate] = isFirstLaunchAfterUpdate()
        dict[TealiumLifecycleKey.isFirstWakeThisMonth] = isFirstWakeThisMonth()
        dict[TealiumLifecycleKey.isFirstWakeToday] = isFirstWakeToday()
        dict[TealiumLifecycleKey.lastLaunchDate] = lastLaunchDate(type: type)?.iso8601String
        dict[TealiumLifecycleKey.lastWakeDate] = lastWakeDate(type: type)?.iso8601String
        dict[TealiumLifecycleKey.lastSleepDate] = lastSleepDate()?.iso8601String
        dict[TealiumLifecycleKey.launchCount] = String(countLaunch)
        dict[TealiumLifecycleKey.priorSecondsAwake] = priorSecondsAwake()
        dict[TealiumLifecycleKey.secondsAwake] = secondsAwake(toDate: forDate)
        dict[TealiumLifecycleKey.sleepCount] = String(countSleep)
        dict[TealiumLifecycleKey.type] = type
        dict[TealiumLifecycleKey.totalCrashCount] = String(countCrashTotal)
        dict[TealiumLifecycleKey.totalLaunchCount] = String(countLaunchTotal)
        dict[TealiumLifecycleKey.totalSleepCount] = String(countSleepTotal)
        dict[TealiumLifecycleKey.totalWakeCount] = String(countWakeTotal)
        dict[TealiumLifecycleKey.totalSecondsAwake] = String(totalSecondsAwake)
        dict[TealiumLifecycleKey.wakeCount] = String(countWake)

        if dateLastUpdate != nil {
            // We've just reset values
            dict[TealiumLifecycleKey.updateLaunchDate] = dateLastUpdate?.iso8601String
        }

        return dict
    }

    func isFirstLaunch() -> String? {
        if countLaunchTotal == 1 &&
            countWakeTotal == 1 &&
            countSleepTotal == 0 {
            return TealiumLifecycleValue.yes
        }
        return nil
    }

    /// Check if we're launching for first time after an app version update.
    ///
    /// - Returns: String "true" or nil
    func isFirstLaunchAfterUpdate() -> String? {
        let prior = sessions.beforeLast()
        let current = sessions.last

        if prior?.appVersion == current?.appVersion {
            return nil
        }
        return TealiumLifecycleValue.yes
    }

    func isFirstWakeToday() -> String? {
        // Wakes array has only 1 date - return true
        if sessions.count < 2 {
            return TealiumLifecycleValue.yes
        }

        // Two wake dates on record, if different - return true
        let earlierWake = (sessions.beforeLast()?.wakeDate)!
        let laterWake = (sessions.last?.wakeDate)!
        let earlierDay = Calendar.autoupdatingCurrent.component(.day, from: earlierWake)
        let laterDay = Calendar.autoupdatingCurrent.component(.day, from: laterWake)

        if  laterWake > earlierWake &&
            laterDay != earlierDay {
            return TealiumLifecycleValue.yes
        }
        return nil
    }

    func isFirstWakeThisMonth() -> String? {
        // Wakes array has only 1 date - return true
        if sessions.count < 2 {
            return TealiumLifecycleValue.yes
        }

        // Two wake dates on record, if different - return true
        let earlierWake = (sessions.beforeLast()?.wakeDate)!
        let laterWake = (sessions.last?.wakeDate)!
        let earlier = Calendar.autoupdatingCurrent.component(.month, from: earlierWake)
        let later = Calendar.autoupdatingCurrent.component(.month, from: laterWake)

        if  laterWake > earlierWake &&
            later != earlier {
            return TealiumLifecycleValue.yes
        }
        return nil
    }

    func dayOfWeekLocal(forDate: Date) -> String {
        let day = Calendar.autoupdatingCurrent.component(.weekday, from: forDate)
        return String(day)
    }

    func daysSinceLastWake(type: String?,
                           toDate: Date) -> String? {
        if type == TealiumLifecycleType.sleep.description {
            let earlierDate = sessions.last!.wakeDate
            return daysFrom(earlierDate: earlierDate, laterDate: toDate)
        }
        guard let targetSession = sessions.beforeLast() else {
            // Shouldn't happen
            return nil
        }
        let earlierDate = targetSession.wakeDate
        return daysFrom(earlierDate: earlierDate, laterDate: toDate)
    }

    func daysFrom(earlierDate: Date?, laterDate: Date) -> String? {
        guard let earlyDate = earlierDate else {
            return nil
        }
        let components = Calendar.autoupdatingCurrent.dateComponents([.second], from: earlyDate, to: laterDate)

        // NOTE: This is not entirely accurate as it does not adjust for Daylight Savings -
        //  however this matches up with implementation in Android, and is off by one day after about 172
        //  days have elapsed
        let days = components.second! / (60 * 60 * 24)
        return String(days)
    }

    func hourOfDayLocal(forDate: Date) -> String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: forDate)
        return String(hour)
    }

    func lastLaunchDate(type: String?) -> Date? {
        guard let lastSession = sessions.last else {
            return nil
        }

        if type == TealiumLifecycleType.sleep.description &&
            lastSession.wasLaunch == true {
            return lastSession.wakeDate
        }
        for itr in (0..<(sessions.count - 1)).reversed() {
            let session = sessions[itr]
            if session.wasLaunch == true {
                return session.wakeDate
            }
        }
        // should never happen
        return sessions.first!.wakeDate
    }

    func lastSleepDate() -> Date? {
        if sessions.last == sessions.first {
            return nil
        }
        for itr in (0..<(sessions.count - 1)).reversed() {
            let session = sessions[itr]
            if session.sleepDate != nil {
                return session.sleepDate
            }
        }
        return nil
    }

    func lastWakeDate(type: String?) -> Date? {
        guard let lastSession = sessions.last else {
            return nil
        }

        if type == TealiumLifecycleType.sleep.description {
            return lastSession.wakeDate
        }
        if sessions.last == sessions.first {
            return lastSession.wakeDate
        }

        guard let beforeLastSession = sessions.beforeLast() else {
            return nil
        }
        return beforeLastSession.wakeDate
    }

    func newCrashDetected() -> String? {
        // Still in first session, can't have crashed yet
        if sessions.last == sessions.first {
            return nil
        }
        if sessions.beforeLast()?.secondsElapsed != 0 {
            return nil
        }

        // No sleep recorded in session before current
        return TealiumLifecycleValue.yes
    }

    func secondsAwake(toDate: Date) -> String? {
        guard let lastSession = sessions.last else {
            return nil
        }
        let currentWake = lastSession.wakeDate
        return secondsFrom(earlierDate: currentWake, laterDate: toDate)
    }

    func secondsFrom(earlierDate: Date?, laterDate: Date) -> String? {
        guard let earlyDate = earlierDate else {
            return nil
        }

        let milliseconds = laterDate.timeIntervalSince(earlyDate)
        return String(Int(milliseconds))
    }

    /// Seconds app was awake since last launch. Available only during launch calls.
    ///
    /// - Returns: String of Int Seconds elapsed
    func priorSecondsAwake() -> String? {
        var secondsAggregate = 0
        var count = sessions.count - 1
        if count < 0 { count = 0 }

        for itr in (0..<count) {
            let session = sessions[itr]
            if session.wasLaunch {
                secondsAggregate = 0
            }
            secondsAggregate += session.secondsElapsed
        }
        return String(describing: secondsAggregate)
    }

}

// swiftlint:disable type_body_length
//public class TealiumLifecycle: NSObject, NSCoding {
//
//    var autotracked: String?
//
//    // Counts being tracked as properties instead of processing through
//    //  sessions data every time. Also, not all sessions records will be kept
//    //  to prevent memory bloat.
//    var countLaunch: Int
//    var countSleep: Int
//    var countWake: Int
//    var countCrashTotal: Int
//    var countLaunchTotal: Int
//    var countSleepTotal: Int
//    var countWakeTotal: Int
//    var dateLastUpdate: Date?
//    var totalSecondsAwake: Int
//    var sessionsSize: Int
//    var sessions = [TealiumLifecycleSession]() {
//        didSet {
//            // Limit size of sessions records
//            if sessions.count > sessionsSize &&
//                sessionsSize > 1 {
//                sessions.remove(at: 1)
//            }
//        }
//    }
//
//    /// Constructor. Should only be called at first init after install.
//    ///
//    /// - Parameter date: Date that the object should be created for.
//    override init() {
//        self.countLaunch = 0
//        self.countWake = 0
//        self.countSleep = 0
//        self.countCrashTotal = 0
//        self.countLaunchTotal = 0
//        self.countWakeTotal = 0
//        self.countSleepTotal = 0
//        self.sessionsSize = 100     // Need a wide berth to capture wakes, sleeps, and updates
//        self.totalSecondsAwake = 0
//        super.init()
//    }
//
// MARK: 
//    // MARK: PERSISTENCE SUPPORT
//    required public init?(coder: NSCoder) {
//        self.countLaunch = coder.decodeInteger(forKey: TealiumLifecycleKey.launchCount)
//        self.countSleep = coder.decodeInteger(forKey: TealiumLifecycleKey.sleepCount)
//        self.countWake = coder.decodeInteger(forKey: TealiumLifecycleKey.wakeCount)
//        self.countCrashTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalCrashCount)
//        self.countLaunchTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalLaunchCount)
//        self.countSleepTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalSleepCount)
//        self.countWakeTotal = coder.decodeInteger(forKey: TealiumLifecycleKey.totalWakeCount)
//        self.dateLastUpdate = coder.decodeObject(forKey: TealiumLifecycleKey.lastUpdateDate) as? Date
//        if let savedSessions = coder.decodeObject(forKey: TealiumLifecycleCodingKey.sessions) as? [TealiumLifecycleSession] {
//            self.sessions = savedSessions
//        }
//        self.sessionsSize = coder.decodeInteger(forKey: TealiumLifecycleCodingKey.sessionsSize)
//        self.totalSecondsAwake = coder.decodeInteger(forKey: TealiumLifecycleCodingKey.totalSecondsAwake)
//    }
//
//    public func encode(with: NSCoder) {
//        with.encode(self.countLaunch, forKey: TealiumLifecycleKey.launchCount)
//        with.encode(self.countSleep, forKey: TealiumLifecycleKey.sleepCount)
//        with.encode(self.countWake, forKey: TealiumLifecycleKey.wakeCount)
//        with.encode(self.countCrashTotal, forKey: TealiumLifecycleKey.totalCrashCount)
//        with.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalLaunchCount)
//        with.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalSleepCount)
//        with.encode(self.countLaunchTotal, forKey: TealiumLifecycleKey.totalWakeCount)
//        with.encode(self.dateLastUpdate, forKey: TealiumLifecycleKey.lastUpdateDate)
//        with.encode(self.sessions, forKey: TealiumLifecycleCodingKey.sessions)
//        with.encode(self.sessionsSize)
//        with.encode(self.totalSecondsAwake, forKey: TealiumLifecycleCodingKey.totalSecondsAwake)
//    }
//
// MARK: 
//    // MARK: PUBLIC
//
//    /// Trigger a new launch and return data for it.
//    ///
//    /// - Parameters:
//    ///   - atDate: Date to trigger launch from.
//    ///   - overrideSession: Optional override session. For testing main use case.
//    /// - Returns: Dictionary of variables in a [String:Any] object
//    public func newLaunch(atDate: Date,
//                          overrideSession: TealiumLifecycleSession?) -> [String: Any] {
//        autotracked = TealiumLifecycleValue.yes
//        countLaunch += 1
//        countLaunchTotal += 1
//        countWake += 1
//        countWakeTotal += 1
//
//        let newSession = (overrideSession != nil) ? overrideSession! : TealiumLifecycleSession(withLaunchDate: atDate)
//        sessions.append(newSession)
//
//        if newCrashDetected() == TealiumLifecycleValue.yes {
//            countCrashTotal += 1
//        }
//        if isFirstLaunchAfterUpdate() == TealiumLifecycleValue.yes {
//            resetCountsForNewVersion(forDate: atDate)
//        }
//
//        return self.asDictionary(type: TealiumLifecycleType.launch.description,
//                                 forDate: atDate)
//    }
//
//    /// Trigger a new wake and return data for it.
//    ///
//    /// - Parameters:
//    ///   - atDate: Date to trigger wake from.
//    ///   - overrideSession: Optional override session.
//    /// - Returns: Dictionary of variables in a [String:Any] object
//    public func newWake(atDate: Date, overrideSession: TealiumLifecycleSession?) -> [String: Any] {
//        autotracked = TealiumLifecycleValue.yes
//        countWake += 1
//        countWakeTotal += 1
//
//        let newSession = (overrideSession != nil) ? overrideSession! : TealiumLifecycleSession(withWakeDate: atDate)
//        sessions.append(newSession)
//
//        return self.asDictionary(type: TealiumLifecycleType.wake.description,
//                                 forDate: atDate)
//    }
//
//    /// Trigger a new sleep and return data for it.
//    ///
//    /// - Parameter atDate: Date to set sleep to.
//    /// - Returns: Dictionary of variables in a [String:Any] object
//    public func newSleep(atDate: Date) -> [String: Any] {
//        autotracked = TealiumLifecycleValue.yes
//        countSleep += 1
//        countSleepTotal += 1
//
//        guard let currentSession = sessions.last else {
//            // Sleep call somehow made prior to the first launch event
//            return [:]
//        }
//
//        currentSession.sleepDate = atDate
//        self.totalSecondsAwake += currentSession.secondsElapsed
//        return self.asDictionary(type: TealiumLifecycleType.sleep.description,
//                                 forDate: atDate)
//    }
//
//    public func newTrack(atDate: Date) -> [String: Any] {
//        guard sessions.last != nil else {
//            // Track request before launch processed
//            return [:]
//        }
//
//        autotracked = nil
//        return self.asDictionary(type: nil,
//                                 forDate: atDate)
//    }
//
// MARK: 
//    // MARK: INTERNAL RESETS
//    func resetCountsForNewVersion(forDate: Date) {
//        countWake = 1
//        countLaunch = 1
//        countSleep = 0
//        dateLastUpdate = forDate
//    }
//
// MARK: 
//    // MARK: INTERNAL HELPERS
//
//    func asDictionary(type: String?,
//                      forDate: Date) -> [String: Any] {
//        var dict = [String: Any]()
//
//        let firstSession = sessions.first
//
//        dict[TealiumLifecycleKey.autotracked] = self.autotracked
//        if type == TealiumLifecycleType.launch.description {
//            dict[TealiumLifecycleKey.didDetectCrash] = newCrashDetected()
//        }
//        dict[TealiumLifecycleKey.dayOfWeek] = dayOfWeekLocal(forDate: forDate)
//        dict[TealiumLifecycleKey.daysSinceFirstLaunch] = daysFrom(earlierDate: firstSession?.wakeDate, laterDate: forDate)
//        dict[TealiumLifecycleKey.daysSinceLastUpdate] = daysFrom(earlierDate: dateLastUpdate, laterDate: forDate)
//        dict[TealiumLifecycleKey.daysSinceLastWake] = daysSinceLastWake(type: type, toDate: forDate)
//        dict[TealiumLifecycleKey.firstLaunchDate] = firstSession?.wakeDate?.iso8601String
//        dict[TealiumLifecycleKey.firstLaunchDateMMDDYYYY] = firstSession?.wakeDate?.mmDDYYYYString
//        dict[TealiumLifecycleKey.hourOfDayLocal] = hourOfDayLocal(forDate: forDate)
//        dict[TealiumLifecycleKey.isFirstLaunch] = isFirstLaunch()
//        dict[TealiumLifecycleKey.isFirstLaunchUpdate] = isFirstLaunchAfterUpdate()
//        dict[TealiumLifecycleKey.isFirstWakeThisMonth] = isFirstWakeThisMonth()
//        dict[TealiumLifecycleKey.isFirstWakeToday] = isFirstWakeToday()
//        dict[TealiumLifecycleKey.lastLaunchDate] = lastLaunchDate(type: type)?.iso8601String
//        dict[TealiumLifecycleKey.lastWakeDate] = lastWakeDate(type: type)?.iso8601String
//        dict[TealiumLifecycleKey.lastSleepDate] = lastSleepDate()?.iso8601String
//        dict[TealiumLifecycleKey.launchCount] = String(countLaunch)
//        dict[TealiumLifecycleKey.priorSecondsAwake] = priorSecondsAwake()
//        dict[TealiumLifecycleKey.secondsAwake] = secondsAwake(toDate: forDate)
//        dict[TealiumLifecycleKey.sleepCount] = String(countSleep)
//        dict[TealiumLifecycleKey.type] = type
//        dict[TealiumLifecycleKey.totalCrashCount] = String(countCrashTotal)
//        dict[TealiumLifecycleKey.totalLaunchCount] = String(countLaunchTotal)
//        dict[TealiumLifecycleKey.totalSleepCount] = String(countSleepTotal)
//        dict[TealiumLifecycleKey.totalWakeCount] = String(countWakeTotal)
//        dict[TealiumLifecycleKey.totalSecondsAwake] = String(totalSecondsAwake)
//        dict[TealiumLifecycleKey.wakeCount] = String(countWake)
//
//        if dateLastUpdate != nil {
//            // We've just reset values
//            dict[TealiumLifecycleKey.updateLaunchDate] = dateLastUpdate?.iso8601String
//        }
//
//        return dict
//    }
//
//    func isFirstLaunch() -> String? {
//        if countLaunchTotal == 1 &&
//            countWakeTotal == 1 &&
//            countSleepTotal == 0 {
//            return TealiumLifecycleValue.yes
//        }
//        return nil
//    }
//
//    /// Check if we're launching for first time after an app version update.
//    ///
//    /// - Returns: String "true" or nil
//    func isFirstLaunchAfterUpdate() -> String? {
//        let prior = sessions.beforeLast()
//        let current = sessions.last
//
//        if prior?.appVersion == current?.appVersion {
//            return nil
//        }
//        return TealiumLifecycleValue.yes
//    }
//
//    func isFirstWakeToday() -> String? {
//        // Wakes array has only 1 date - return true
//        if sessions.count < 2 {
//            return TealiumLifecycleValue.yes
//        }
//
//        // Two wake dates on record, if different - return true
//        let earlierWake = (sessions.beforeLast()?.wakeDate)!
//        let laterWake = (sessions.last?.wakeDate)!
//        let earlierDay = Calendar.autoupdatingCurrent.component(.day, from: earlierWake)
//        let laterDay = Calendar.autoupdatingCurrent.component(.day, from: laterWake)
//
//        if  laterWake > earlierWake &&
//            laterDay != earlierDay {
//            return TealiumLifecycleValue.yes
//        }
//        return nil
//    }
//
//    func isFirstWakeThisMonth() -> String? {
//        // Wakes array has only 1 date - return true
//        if sessions.count < 2 {
//            return TealiumLifecycleValue.yes
//        }
//
//        // Two wake dates on record, if different - return true
//        let earlierWake = (sessions.beforeLast()?.wakeDate)!
//        let laterWake = (sessions.last?.wakeDate)!
//        let earlier = Calendar.autoupdatingCurrent.component(.month, from: earlierWake)
//        let later = Calendar.autoupdatingCurrent.component(.month, from: laterWake)
//
//        if  laterWake > earlierWake &&
//            later != earlier {
//            return TealiumLifecycleValue.yes
//        }
//        return nil
//    }
//
//    func dayOfWeekLocal(forDate: Date) -> String {
//        let day = Calendar.autoupdatingCurrent.component(.weekday, from: forDate)
//        return String(day)
//    }
//
//    func daysSinceLastWake(type: String?,
//                           toDate: Date) -> String? {
//        if type == TealiumLifecycleType.sleep.description {
//            let earlierDate = sessions.last!.wakeDate
//            return daysFrom(earlierDate: earlierDate, laterDate: toDate)
//        }
//        guard let targetSession = sessions.beforeLast() else {
//            // Shouldn't happen
//            return nil
//        }
//        let earlierDate = targetSession.wakeDate
//        return daysFrom(earlierDate: earlierDate, laterDate: toDate)
//    }
//
//    func daysFrom(earlierDate: Date?, laterDate: Date) -> String? {
//        guard let earlyDate = earlierDate else {
//            return nil
//        }
//        let components = Calendar.autoupdatingCurrent.dateComponents([.second], from: earlyDate, to: laterDate)
//
//        // NOTE: This is not entirely accurate as it does not adjust for Daylight Savings -
//        //  however this matches up with implementation in Android, and is off by one day after about 172
//        //  days have elapsed
//        let days = components.second! / (60 * 60 * 24)
//        return String(days)
//    }
//
//    func hourOfDayLocal(forDate: Date) -> String {
//        let hour = Calendar.autoupdatingCurrent.component(.hour, from: forDate)
//        return String(hour)
//    }
//
//    func lastLaunchDate(type: String?) -> Date? {
//        guard let lastSession = sessions.last else {
//            return nil
//        }
//
//        if type == TealiumLifecycleType.sleep.description &&
//            lastSession.wasLaunch == true {
//            return lastSession.wakeDate
//        }
//        for itr in (0..<(sessions.count - 1)).reversed() {
//            let session = sessions[itr]
//            if session.wasLaunch == true {
//                return session.wakeDate
//            }
//        }
//        // should never happen
//        return sessions.first!.wakeDate
//    }
//
//    func lastSleepDate() -> Date? {
//        if sessions.last == sessions.first {
//            return nil
//        }
//        for itr in (0..<(sessions.count - 1)).reversed() {
//            let session = sessions[itr]
//            if session.sleepDate != nil {
//                return session.sleepDate
//            }
//        }
//        return nil
//    }
//
//    func lastWakeDate(type: String?) -> Date? {
//        guard let lastSession = sessions.last else {
//            return nil
//        }
//
//        if type == TealiumLifecycleType.sleep.description {
//            return lastSession.wakeDate
//        }
//        if sessions.last == sessions.first {
//            return lastSession.wakeDate
//        }
//
//        guard let beforeLastSession = sessions.beforeLast() else {
//            return nil
//        }
//        return beforeLastSession.wakeDate
//    }
//
//    func newCrashDetected() -> String? {
//        // Still in first session, can't have crashed yet
//        if sessions.last == sessions.first {
//            return nil
//        }
//        if sessions.beforeLast()?.secondsElapsed != 0 {
//            return nil
//        }
//
//        // No sleep recorded in session before current
//        return TealiumLifecycleValue.yes
//    }
//
//    func secondsAwake(toDate: Date) -> String? {
//        guard let lastSession = sessions.last else {
//            return nil
//        }
//        let currentWake = lastSession.wakeDate
//        return secondsFrom(earlierDate: currentWake, laterDate: toDate)
//    }
//
//    func secondsFrom(earlierDate: Date?, laterDate: Date) -> String? {
//        guard let earlyDate = earlierDate else {
//            return nil
//        }
//
//        let milliseconds = laterDate.timeIntervalSince(earlyDate)
//        return String(Int(milliseconds))
//    }
//
//    /// Seconds app was awake since last launch. Available only during launch calls.
//    ///
//    /// - Returns: String of Int Seconds elapsed
//    func priorSecondsAwake() -> String? {
//        var secondsAggregate: Int = 0
//        var count = sessions.count - 1
//        if count < 0 { count = 0 }
//
//        for itr in (0..<count) {
//            let session = sessions[itr]
//            if session.wasLaunch {
//                secondsAggregate = 0
//            }
//            secondsAggregate += session.secondsElapsed
//        }
//        return String(describing: secondsAggregate)
//    }
//
//}
