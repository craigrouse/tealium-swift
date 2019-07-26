//
//  TealiumLoggerModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 10/5/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation

// MARK: 
// MARK: CONSTANTS

#if logger
import TealiumCore
#endif

enum TealiumLoggerKey {
    static let moduleName = "logger"
    static let logLevelConfig = "com.tealium.logger.loglevel"
    static let shouldEnable = "com.tealium.logger.enable"
}

// MARK: 
// MARK: EXTENSIONS

public extension Tealium {

    func logger() -> TealiumLogger? {
        guard let module = modulesManager.getModule(forName: TealiumLoggerKey.moduleName) as? TealiumLoggerModule else {
            return nil
        }

        return module.logger
    }
}

public extension TealiumConfig {

    func getLogLevel() -> TealiumLogLevel {
        if let level = self.optionalData[TealiumLoggerKey.logLevelConfig] as? TealiumLogLevel {
            return level
        }

        // Default
        return defaultTealiumLogLevel
    }

    func setLogLevel(logLevel: TealiumLogLevel) {
        self.optionalData[TealiumLoggerKey.logLevelConfig] = logLevel
    }
}

// MARK: 
// MARK: MODULE

/// Module for adding basic console log output.
class TealiumLoggerModule: TealiumModule {

    var logger: TealiumLogger?

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumLoggerKey.moduleName,
                                   priority: 100,
                                   build: 3,
                                   enabled: true)
    }

    override func enable(_ request: TealiumEnableRequest) {
        isEnabled = true

        if logger == nil {
            let config = request.config
            let logLevel = config.getLogLevel()
            let id = "\(config.account):\(config.profile):\(config.environment)"
            logger = TealiumLogger(loggerId: id, logLevel: logLevel)
        }

        delegate?.tealiumModuleRequests(module: self,
                                        process: TealiumReportNotificationsRequest())
        didFinish(request)
    }

    override func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        logger = nil
        didFinish(request)
    }

    override func handleReport(_ request: TealiumRequest) {
        let moduleResponses = request.moduleResponses

        switch request {
        case is TealiumEnableRequest:
            moduleResponses.forEach ({ response in
                logEnable(response)
            })
        case is TealiumDisableRequest:
            moduleResponses.forEach ({ response in
                logDisable(response)
            })
        case is TealiumLoadRequest:
            logLoad(moduleResponses)
        case is TealiumSaveRequest:
            logSave(moduleResponses)
        case is TealiumReportRequest:
            logReport(request)
        case let request as TealiumTrackRequest:
            logTrack(request: request, responses: moduleResponses)
        case let request as TealiumBatchTrackRequest:
            let requests = request.trackRequests
            requests.forEach {
                logTrack(request: $0, responses: moduleResponses)
            }
        default:
            // Only print errors if detected in module responses.
            moduleResponses.forEach({ response in
                logError(response)
            })
        }
    }

    func logEnable(_ response: TealiumModuleResponse) {
        let successMessage = response.success == true ? "ENABLED" : "FAILED TO ENABLE"
        let message = "\(response.moduleName): \(successMessage)"
        logger?.log(message: message,
                    logLevel: .verbose)
    }

    func logDisable(_ response: TealiumModuleResponse) {
        let successMessage = response.success == true ? "ENABLED" : "FAILED TO DISABLE"
        let message = "\(response.moduleName): \(successMessage)"
        logger?.log(message: message,
                        logLevel: .verbose)
    }

    func logError(_ response: TealiumModuleResponse) {
        guard let error = response.error else {
            return
        }
        let message = "\(response.moduleName): Encountered error: \(error)"
        logger?.log(message: message,
                        logLevel: .errors)
    }

    func logLoad(_ responses: [TealiumModuleResponse]) {
        var successes = 0
        // Swift's native Error type seems to be leaky. Using Any fixes the leak.
        var errors = [Error]()
        responses.forEach { response in
            if response.success == true {
                successes += 1
            }
            if let error = response.error {
                errors.append(error)
            }
        }
        if successes > 0 && errors.count == 0 {
            return
        } else if successes > 0 && errors.count > 0 {
            var message = ""
            errors.forEach({ err in
                message += "\(err.localizedDescription)\n"
            })
            logger?.log(message: message, logLevel: .verbose)
            return
        }
        // Failed to load
        let message = "FAILED to load data. Possibly no data storage modules enabled."
        logger?.log(message: message,
                    logLevel: .errors)
    }

    func logReport(_ request: TealiumRequest) {
        guard let request = request as? TealiumReportRequest else {
            return
        }
        let message = "\(request.message)"
        logger?.log(message: message,
                    logLevel: .verbose)
    }

    func logSave(_ responses: [TealiumModuleResponse]) {
        var successes = 0
        responses.forEach { response in
            if response.success == true {
                successes += 1
            }
        }
        if successes > 0 {
            return
        }
        // Failed to load
        let message = "FAILED to save data. Possibly no storage persistence modules enabled."
        logger?.log(message: message,
                    logLevel: .errors)
    }

    func logTrack(request: TealiumTrackRequest,
                  responses: [TealiumModuleResponse]) {
        let trackNumber = Tealium.numberOfTrackRequests.incrementAndGet()
        var message = """
        \n=====================================
        ▶️[Track #\(trackNumber)]: \(request.trackDictionary[TealiumKey.event] as? String ?? "")
        =====================================\n
        """

        if responses.count > 0 {
            message += "Module Responses:\n"
        }

        responses.enumerated().forEach {
            let index = $0.offset + 1
            let response = $0.element
            let successMessage = response.success == true ? "SUCCESSFUL TRACK ✅" : "FAILED TO TRACK ⚠️"
            var trackMessage = "\(index). \(response.moduleName): \(successMessage)"
            if !response.success, let error = response.error {
             trackMessage += "\n🔺 \(error.localizedDescription)"
            }
            message = "\(message)\(trackMessage)\n"
        }

        message += "\nTRACK REQUEST PAYLOAD:\n"

        if let jsonString = request.trackDictionary.toJSONString() {
            message += jsonString
        } else {
            // peculiarity with AnyObject printing: quotes are randomly omitted from values
            message += "\(request.trackDictionary as AnyObject)"
        }

        message = "\(message)[Track # \(trackNumber)] ⏹\n"

        logger?.log(message: message,
                    logLevel: .verbose)
    }

    func logWithPrefix(fromModule: TealiumModule,
                       message: String,
                       logLevel: TealiumLogLevel) {

        let moduleConfig = type(of: fromModule).moduleConfig()
        let newMessage = "\(moduleConfig.name) module.\(moduleConfig.build): \(message)"
        logger?.log(message: newMessage, logLevel: logLevel)
    }

}
