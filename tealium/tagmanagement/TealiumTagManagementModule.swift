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
    var pendingTrackRequests = [TealiumTrackRequest]()

    override public class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumTagManagementKey.moduleName,
                                   priority: 1100,
                                   build: 3,
                                   enabled: true)
    }

    // NOTE: UIWebview, the primary element of TealiumTagManagement cannot run in XCTests.
    #if TEST
    #else

    // TODO: Finish implementation!!!!
    override public func handle(_ request: TealiumRequest) {
        switch request {
        case let request as TealiumEnableRequest:
            enable(request)
        case let request as TealiumDisableRequest:
            disable(request)
        case let request as TealiumTrackRequest:
            track(request)
        case let request as TealiumBatchTrackRequest:
            batchTrack(request)
        default:
            didFinish(request)
        }
    }

    /// Enables the module and sets up the webview instance
    ///
    /// - Parameter request: TealiumEnableRequest - the request from the core library to enable this module
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
                    if let err = error {
//                        self.didFailToFinish(request,
//                                             error: err)
                        let logger = TealiumLogger(loggerId: TealiumTagManagementModule.moduleConfig().name, logLevel: request.config.getLogLevel())
                        _ = logger.log(message: (error?.localizedDescription ?? "Tag Management Error"), logLevel: .warnings)
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
    /// - Parameter request: TealiumDisableRequest indicating that the module should be disabled
    override public func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        DispatchQueue.main.async {
            self.tagManagement?.disable()
        }
        didFinish(request,
                  info: nil)
    }

    /// Handles the track request and forwards to the webview for processing
    ///
    /// - Parameter track: TealiumTrackRequest to be evaluated
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
                    // TODO: Proper error logging
                    _ = self.errorState.incrementAndGet()
                    self.pendingTrackRequests.append(track)
                }
            }
            return
        }

        TealiumQueues.backgroundConcurrentQueue.write {
            let pending = self.pendingTrackRequests
            pending.forEach {
                self.track($0)
            }
            self.pendingTrackRequests = [TealiumTrackRequest]()
        }

        var newTrackData = track.trackDictionary
        newTrackData[TealiumKey.dispatchService] = TealiumTagManagementKey.moduleName
        var newTrack = TealiumTrackRequest(data: newTrackData, completion: track.completion)
        newTrack.moduleResponses = track.moduleResponses
        dispatchTrack(newTrack)
    }

    /// Handles the batch track request and forwards to the webview for processing
    ///
    /// - Parameter track: TealiumTrackRequest to be evaluated
    public func batchTrack(_ track: TealiumBatchTrackRequest) {
        if isEnabled == false {
            // Ignore while disabled
            didFinishWithNoResponse(track)
            return
        }

        track.trackRequests.forEach { [unowned self] track in
            self.track(track)
        }
    }

    /// Called when the module has finished processing the request
    ///
    /// - Parameters:
    /// - request: TealiumRequest that the module has finished processing
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
    /// - request: TealiumRequest that the module has failed to process
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
    /// - Parameter track: TealiumTrackRequest to be sent to the webview
    func dispatchTrack(_ track: TealiumTrackRequest) {
        // Dispatch to main thread since webview requires main thread.
        DispatchQueue.main.async {
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
        }

    }
    #endif
}
