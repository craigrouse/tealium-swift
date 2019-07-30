//
//  TealiumTagManagementModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 12/14/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation
#if tagmanagement
import TealiumCore
#endif

// MARK: MODULE SUBCLASS
public class TealiumTagManagementModule: TealiumModule {
    var tagManagement: TealiumTagManagementProtocol?
    var remoteCommandResponseObserver: NSObjectProtocol?
    var errorState = AtomicInteger()
    var pendingTrackRequests = [TealiumRequest]()

    override public class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumTagManagementKey.moduleName,
                                   priority: 1100,
                                   build: 3,
                                   enabled: true)
    }

    // NOTE: UIWebview, the primary element of TealiumTagManagement cannot run in XCTests.
    #if TEST
    #else

    override public func handle(_ request: TealiumRequest) {
        switch request {
        case let request as TealiumEnableRequest:
            enable(request)
        case let request as TealiumDisableRequest:
            disable(request)
        case let request as TealiumTrackRequest:
            prepareTrack(request)
        case let request as TealiumBatchTrackRequest:
            prepareTrack(request)
        default:
            didFinish(request)
        }
    }

    /// Enables the module and sets up the webview instance
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override public func enable(_ request: TealiumEnableRequest) {

//        let cache = TealiumAssetCache()

        if request.config.getShouldUseLegacyWebview() == true {
            self.tagManagement = TealiumTagManagementUIWebView()
        } else if #available(iOS 11.0, *) {
            self.tagManagement = TealiumTagManagementWKWebView()
        } else {
            self.tagManagement = TealiumTagManagementUIWebView()
        }

        let config = request.config
        enableNotifications()
        if config.optionalData[TealiumTagManagementConfigKey.disable] as? Bool == true {
            DispatchQueue.main.async {
                self.tagManagement?.disable()
            }
            self.didFinish(request,
                           info: nil)
            return
        }

        DispatchQueue.main.async {
            self.tagManagement?.enable(webviewURL: config.webviewURL(), shouldMigrateCookies: true, delegates: config.getWebViewDelegates(), view: config.getRootView()) { _, error in
                TealiumQueues.backgroundConcurrentQueue.write {
                    if let error = error {
                        let logger = TealiumLogger(loggerId: TealiumTagManagementModule.moduleConfig().name, logLevel: request.config.getLogLevel())
                        logger.log(message: (error.localizedDescription), logLevel: .warnings)
                        _ = self.errorState.incrementAndGet()
                    }
                    self.isEnabled = true
                    self.didFinish(request)
                }
            }
        }
    }

    /// Listens for notifications from the Remote Commands module. Typically these will be responses from a Remote Command that has finished executing.
    func enableNotifications() {
        remoteCommandResponseObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(TealiumKey.jsNotificationName), object: nil, queue: OperationQueue.main) { notification in
            if let userInfo = notification.userInfo, let jsCommand = userInfo[TealiumKey.jsCommand] as? String {
                // Webview instance will ensure this is processed on the main thread
                self.tagManagement?.evaluateJavascript(jsCommand, nil)
            }
        }
    }

    /// Disables the Tag Management module
    ///
    /// - parameter request: `TealiumDisableRequest` indicating that the module should be disabled
    override public func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        DispatchQueue.main.async {
            self.tagManagement?.disable()
        }
        didFinish(request,
                  info: nil)
    }

    func prepareTrack(_ track: TealiumRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(track)
            return
        }

        switch track {
        case let track as TealiumTrackRequest:
            self.track(prepareForDispatch(track))
        case let track as TealiumBatchTrackRequest:
            var requests = track.trackRequests
            requests = requests.map {
                prepareForDispatch($0)
            }
            var newRequest = TealiumBatchTrackRequest(trackRequests: requests, completion: track.completion)
            newRequest.moduleResponses = track.moduleResponses
            self.batchTrack(newRequest)
        default:
            self.didFinishWithNoResponse(track)
            return
        }
    }

    func prepareForDispatch(_ request: TealiumTrackRequest) -> TealiumTrackRequest {
        var newTrack = request.trackDictionary
        newTrack[TealiumKey.dispatchService] = TealiumTagManagementKey.moduleName
        var newRequest = TealiumTrackRequest(data: newTrack, completion: request.completion)
        newRequest.moduleResponses = request.moduleResponses
        return newRequest
    }

    /// Handles the track request and forwards to the webview for processing
    ///
    /// - parameter track: `TealiumTrackRequest` to be evaluated
    override public func track(_ track: TealiumTrackRequest) {
        if isEnabled == false {
            // Ignore while disabled
            didFinishWithNoResponse(track)
            return
        }

        if self.errorState.value > 0 {
            self.tagManagement?.reload { success, _, _ in
                if success {
                    self.errorState.value = 0
                    self.track(track)
                } else {
                    _ = self.errorState.incrementAndGet()
                    self.queue(track)
                    let reportRequest = TealiumReportRequest(message: "WebView load failed. Will retry.")
                    self.delegate?.tealiumModuleRequests(module: self, process: reportRequest)
                }
            }
            return
        }

        let pending = self.pendingTrackRequests
        self.pendingTrackRequests = [TealiumRequest]()
        pending.forEach {
            self.prepareTrack($0)
        }

        var newTrack = TealiumTrackRequest(data: track.trackDictionary, completion: track.completion)
        newTrack.moduleResponses = track.moduleResponses
        dispatchTrack(newTrack)
    }

    /// Handles the batch track request and forwards to the webview for processing
    ///
    /// - parameter track: `TealiumTrackRequest` to be evaluated
    public func batchTrack(_ track: TealiumBatchTrackRequest) {
        if isEnabled == false {
            // Ignore while disabled
            didFinishWithNoResponse(track)
            return
        }

        dispatchTrack(track)
    }

    func queue(_ request: TealiumRequest) {
        guard request is TealiumTrackRequest || request is TealiumBatchTrackRequest else {
            return
        }

        switch request {
        case let request as TealiumBatchTrackRequest:
            var requests = request.trackRequests
            requests = requests.map {
                var trackData = $0.trackDictionary, track = $0
                trackData[TealiumKey.wasQueued] = true
                trackData[TealiumKey.queueReason] = "Tag Management Webview Not Ready"
                track.data = trackData.encodable
                return track
            }
            self.pendingTrackRequests.append(TealiumBatchTrackRequest(trackRequests: requests, completion: request.completion))
        case let request as TealiumTrackRequest:
            var track = request
            var trackData = track.trackDictionary
            trackData[TealiumKey.wasQueued] = true
            trackData[TealiumKey.queueReason] = "Tag Management Webview Not Ready"
            track.data = trackData.encodable
            self.pendingTrackRequests.append(track)
        default:
            return
        }
    }

    /// Called when the module has finished processing the request
    ///
    /// - Parameters:
    /// - request: `TealiumRequest` that the module has finished processing
    /// - info: [String: Any]? optional dictionary containing additional information from the module about how it handled the request
    func didFinish(_ request: TealiumRequest,
                   info: [String: Any]?) {
        var newRequest = request
        var response = TealiumModuleResponse(moduleName: type(of: self).moduleConfig().name,
                                             success: true,
                                             error: nil)
        response.info = info
        newRequest.moduleResponses.append(response)

        self.delegate?.tealiumModuleFinished(module: self,
                                             process: newRequest)
    }

    /// Called when the module has failed to process the request
    ///
    /// - Parameters:
    /// - request: `TealiumRequest` that the module has failed to process
    /// - info: [String: Any]? optional dictionary containing additional information from the module about how it handled the request
    /// - error: Error reason
    func didFailToFinish(_ request: TealiumRequest,
                         info: [String: Any]?,
                         error: Error) {
        var newRequest = request
        var response = TealiumModuleResponse(moduleName: type(of: self).moduleConfig().name,
                                             success: false,
                                             error: error)
        response.info = info
        newRequest.moduleResponses.append(response)

        self.delegate?.tealiumModuleFinished(module: self,
                                             process: newRequest)
    }

    /// Sends the track request to the webview
    ///
    /// - parameter track: `TealiumTrackRequest` to be sent to the webview
    func dispatchTrack(_ request: TealiumRequest) {
        switch request {
        case let track as TealiumBatchTrackRequest:
                // Webview has failed for some reason
                if self.tagManagement?.isWebViewReady() == false {
                    TealiumQueues.backgroundConcurrentQueue.write {
                        self.didFailToFinish(track,
                                             info: nil,
                                             error: TealiumTagManagementError.webViewNotYetReady)
                    }
                    return
                }
                var allTrackData = [[String: Any]]()

                track.trackRequests.forEach {
                        allTrackData.append($0.trackDictionary)
                }

                    #if TEST
                    #else
                    self.tagManagement?.trackMultiple(allTrackData) { success, info, error in
                        TealiumQueues.backgroundConcurrentQueue.write {
                            track.completion?(success, info, error)
                            if error != nil {
                                self.didFailToFinish(track,
                                                     info: info,
                                                     error: error!)
                                return
                            }
                            self.didFinish(track,
                                           info: info)
                        }
                    }
                    #endif
        case let track as TealiumTrackRequest:
                // Webview has failed for some reason
                if self.tagManagement?.isWebViewReady() == false {
                    TealiumQueues.backgroundConcurrentQueue.write {
                        self.didFailToFinish(track,
                                             info: nil,
                                             error: TealiumTagManagementError.webViewNotYetReady)
                    }
                    return
                }

                #if TEST
                #else
                self.tagManagement?.track(track.trackDictionary) { success, info, error in
                    TealiumQueues.backgroundConcurrentQueue.write {
                        track.completion?(success, info, error)
                        if error != nil {
                            self.didFailToFinish(track,
                                                 info: info,
                                                 error: error!)
                            return
                        }
                        self.didFinish(track,
                                       info: info)
                    }
                }
                #endif
        default:
            let reportRequest = TealiumReportRequest(message: "Unexpected request type received. Will not process.")
            self.delegate?.tealiumModuleRequests(module: self, process: reportRequest)
            return
        }
    }

    #endif
}
