//
//  TealiumCollectModule.swift
//  tealium-swift
//
//  Created by Jason Koo on 10/7/16.
//  Copyright © 2016 Tealium, Inc. All rights reserved.
//

import Foundation
#if collect
import TealiumCore
#endif

/// Dispatch Service Module for sending track data to the Tealium Collect or custom endpoint.
class TealiumCollectModule: TealiumModule {

    var collect: TealiumCollectProtocol?
    var config: TealiumConfig?
    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumCollectKey.moduleName,
                                   priority: 1050,
                                   build: 4,
                                   enabled: true)
    }

    override func handle(_ request: TealiumRequest) {
        switch request {
        case let request as TealiumEnableRequest:
            enable(request)
        case let request as TealiumTrackRequest:
            prepareTrack(request)
        case let request as TealiumBatchTrackRequest:
            prepareTrack(request)
        default:
            didFinish(request)
        }
    }

    /// Enables the module and loads sets up a dispatcher
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override func enable(_ request: TealiumEnableRequest) {
        isEnabled = true
        config = request.config
        if self.collect == nil {
            // Collect dispatch service
            let urlString = config?.optionalData[TealiumCollectKey.overrideCollectUrl] as? String
            // check if should use legacy (GET) dispatch method
            if config?.optionalData[TealiumCollectKey.legacyDispatchMethod] as? Bool == true {
                let urlString = urlString ?? TealiumCollect.defaultBaseURLString()
                self.collect = TealiumCollect(baseURL: urlString)
                didFinish(request)
            } else {
                let urlString = urlString ?? TealiumCollectPostDispatcher.defaultDispatchBaseURL
                self.collect = TealiumCollectPostDispatcher(dispatchURL: urlString) { _ in
                    self.didFinish(request)
                }
            }
        }
    }

    func prepareTrack(_ track: TealiumRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(track)
            return
        }

        guard collect != nil else {
            didFailToFinish(track,
                            error: TealiumCollectError.collectNotInitialized)
            return
        }

        switch track {
        case let track as TealiumTrackRequest:
            guard track.trackDictionary[TealiumKey.event] as? String != TealiumKey.updateConsentCookieEventName else {
                didFinishWithNoResponse(track)
                return
            }
            self.track(prepareForDispatch(track))
        case let track as TealiumBatchTrackRequest:
            var requests = track.trackRequests
            requests = requests.filter {
                $0.trackDictionary[TealiumKey.event] as? String != TealiumKey.updateConsentCookieEventName
            }.map {
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

    /// Adds relevant info to the track request, then passes the request to a dipatcher for processing
    ///
    /// - parameter track: `TealiumTrackRequest` to be dispatched
    override func track(_ track: TealiumTrackRequest) {
        guard let collect = collect else {
            didFinishWithNoResponse(track)
            return
        }

        // Send the current track call
        dispatch(track,
                 collect: collect)
    }

    /// Adds relevant info to the track request, then passes the request to a dipatcher for processing
    ///
    /// - parameter track: `TealiumTrackRequest` to be dispatched
    func batchTrack(_ request: TealiumBatchTrackRequest) {
        guard let collect = collect else {
            didFinishWithNoResponse(request)
            return
        }

        var requests = [TealiumTrackRequest]()

        request.trackRequests.forEach {
            requests.append(prepareForDispatch($0))
        }

        let newBatchTrack = TealiumBatchTrackRequest(trackRequests: requests, completion: request.completion)

        guard let compressed = newBatchTrack.compressed() else {
            // TODO: Logging
            return
        }

        collect.dispatchBulk(data: compressed) { _, info, _ in
            // TODO: logging
            self.didFinish(request, info: info)
        }
    }

    func prepareForDispatch(_ request: TealiumTrackRequest) -> TealiumTrackRequest {
        var newTrack = request.trackDictionary
        if newTrack[TealiumKey.account] == nil,
            newTrack[TealiumKey.profile] == nil {
            newTrack[TealiumKey.account] = config?.account
            newTrack[TealiumKey.profile] = config?.profile
        }
        return TealiumTrackRequest(data: newTrack, completion: request.completion)
    }

    /// Called when the module successfully finished processing a request
    ///
    /// - parameter request: `TealiumRequest` that was processed
    /// - parameter info: `[String: Any]?` containing additional information about the request processing
    func didFinish(_ request: TealiumRequest,
                   info: [String: Any]?) {
        var newRequest = request
        var response = TealiumModuleResponse(moduleName: type(of: self).moduleConfig().name,
                                             success: true,
                                             error: nil)
        response.info = info
        newRequest.moduleResponses.append(response)

        delegate?.tealiumModuleFinished(module: self,
                                        process: newRequest)
    }

    /// Called when the module failed for to complete a request
    ///
    /// - parameter request: `TealiumRequest` that failed
    /// - parameter info: `[String: Any]? `containing information about the failure
    /// - parameter error: `Error` with precise information about the failure
    func didFailToFinish(_ request: TealiumRequest,
                         info: [String: Any]?,
                         error: Error) {
        var newRequest = request
        var response = TealiumModuleResponse(moduleName: type(of: self).moduleConfig().name,
                                             success: false,
                                             error: error)
        response.info = info
        newRequest.moduleResponses.append(response)
        delegate?.tealiumModuleFinished(module: self,
                                        process: newRequest)
    }

    /// Sends a track request to a specified dispatcher
    ///
    /// - parameter track: `TealiumTrackRequest` to be processed
    /// - parameter collect: `TealiumCollectProtocol` instance to be used for this dispatch
    func dispatch(_ track: TealiumTrackRequest,
                  collect: TealiumCollectProtocol) {

        var newData = track.trackDictionary
        newData[TealiumKey.dispatchService] = TealiumCollectKey.moduleName

        if let profileOverride = config?.optionalData[TealiumCollectKey.overrideCollectProfile] as? String {
            newData[TealiumKey.profile] = profileOverride
        }

        collect.dispatch(data: newData, completion: { success, info, error in

            track.completion?(success, info, error)

            // Let the modules manager know we had a failure.
            if success == false {
                var localError = error
                if localError == nil { localError = TealiumCollectError.unknownIssueWithSend }
                self.didFailToFinish(track,
                                     info: info,
                                     error: localError!)
                return
            }

            var trackInfo = info ?? [String: Any]()
            trackInfo[TealiumKey.dispatchService] = TealiumCollectKey.moduleName
            trackInfo += [TealiumCollectKey.payload: track.trackDictionary]

            // Another message to moduleManager of completed track, this time of
            //  modified track data.
            self.didFinish(track,
                           info: trackInfo)
        })
    }

    /// Disables the module
    ///
    /// - parameter request: `TealiumDisableRequest`
    override func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        self.collect = nil
        didFinish(request)
    }

    deinit {
        self.config = nil
        self.collect = nil
    }

}
