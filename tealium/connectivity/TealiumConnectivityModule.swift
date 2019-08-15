//
//  TealiumConnectivityModule.swift
//  tealium-swift
//
//  Created by Jonathan Wong on 1/10/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation

#if os(watchOS)
#else
import SystemConfiguration
#endif
#if connectivity
import TealiumCore
#endif

class TealiumConnectivityModule: TealiumModule {

    static var connectionType: String?
    static var isConnected: Bool?
    // used to simulate connection status for unit tests
    lazy var connectivity = TealiumConnectivity()
    var config: TealiumConfig?

    @available(*, deprecated, message: "Internal only. Used only for unit tests. Using this method will disable connectivity checks.")
    public static func setConnectionOverride(shouldOverride override: Bool) {
        TealiumConnectivity.forceConnectionOverride = override
    }

    override class func moduleConfig() -> TealiumModuleConfig {
        return TealiumModuleConfig(name: TealiumConnectivityKey.moduleName,
                                   priority: 950,
                                   build: 1,
                                   enabled: true)
    }

    /// Custom handler for incoming module requests
    ///
    /// - parameter request: TealiumRequest to be handled by the module
    override func handle(_ request: TealiumRequest) {
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
            didFinishWithNoResponse(request)
        }
    }

    func prepareTrack(_ track: TealiumRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(track)
            return
        }

        switch track {
        case let track as TealiumTrackRequest:
            self.trackWithConnectivityCheck(prepareForDispatch(track))
        case let track as TealiumBatchTrackRequest:
            var requests = track.trackRequests
            requests = requests.map {
                prepareForDispatch($0)
            }
            var newRequest = TealiumBatchTrackRequest(trackRequests: requests, completion: track.completion)
            newRequest.moduleResponses = track.moduleResponses
            self.trackWithConnectivityCheck(newRequest)
        default:
            self.didFinishWithNoResponse(track)
            return
        }
    }

    func prepareForDispatch(_ request: TealiumTrackRequest) -> TealiumTrackRequest {
        var newData = request.trackDictionary
        // do not add data to queued hits
        if newData[TealiumKey.wasQueued] as? String == nil {
            newData += [TealiumConnectivityKey.connectionType: TealiumConnectivity.currentConnectionType(),
                        TealiumConnectivityKey.connectionTypeLegacy: TealiumConnectivity.currentConnectionType(),
            ]
        }
        var newRequest = TealiumTrackRequest(data: newData, completion: request.completion)
        newRequest.moduleResponses = request.moduleResponses
        return newRequest
    }

    /// Enables the module and starts connectivity monitoring
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override func enable(_ request: TealiumEnableRequest) {
        super.enable(request)
        connectivity.addConnectivityDelegate(delegate: self)
        self.config = request.config
        self.refreshConnectivityStatus()
    }

    /// Handles the track request and queues if no connection available (requires DispatchQueue module)
    ///
    /// - parameter track: `TealiumTrackRequest` to be processed
    func trackWithConnectivityCheck(_ request: TealiumRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(request)
            return
        }

        if TealiumConnectivity.isConnectedToNetwork() == false {
            self.refreshConnectivityStatus()
            // Save in cache
            queue(request)

            // Notify any logger
            let report = TealiumReportRequest(message: "Connectivity: Queued track. No internet connection.")
            delegate?.tealiumModuleRequests(module: self,
                                            process: report)

            // No did finish call. Halting further processing of track within module chain.
            return
        }

        cancelConnectivityRefresh()

        let report = TealiumReportRequest(message: "Connectivity: Sending queued track. Internet connection available.")
        delegate?.tealiumModuleRequests(module: self, process: report)

        didFinishWithNoResponse(request)
    }

    /// Enqueues the track request for later transmission
    ///
    /// - parameter track: `TealiumTrackRequest` to be queued
    func queue(_ track: TealiumRequest) {
        var enqueueRequest: TealiumEnqueueRequest
        switch track {
        case let track as TealiumTrackRequest:
            var newTrack = addQueueData(track)
            newTrack.moduleResponses = track.moduleResponses
            enqueueRequest = TealiumEnqueueRequest(data: newTrack, completion: nil)
        case let track as TealiumBatchTrackRequest:
            var requests = track.trackRequests
            requests = requests.map {
                addQueueData($0)
            }
            var newRequest = TealiumBatchTrackRequest(trackRequests: requests, completion: track.completion)
            newRequest.moduleResponses = track.moduleResponses
            enqueueRequest = TealiumEnqueueRequest(data: newRequest, completion: nil)
        default:
            self.didFinishWithNoResponse(track)
            return
        }

        delegate?.tealiumModuleRequests(module: self, process: enqueueRequest)
    }

    func addQueueData(_ track: TealiumTrackRequest) -> TealiumTrackRequest {
        var newData = track.trackDictionary
        newData[TealiumKey.queueReason] = TealiumConnectivityKey.moduleName
        newData[TealiumKey.wasQueued] = "true"
        return TealiumTrackRequest(data: newData,
                                   completion: track.completion)
    }

    /// Releases all queued track calls for dispatch
    func release() {
        // queue will be released, but will only be allowed to continue if tracking is allowed when track call is resubmitted
        let req = TealiumReleaseQueuesRequest(typeId: "connectivity", moduleResponses: [TealiumModuleResponse]()) { _, _, _ in
            let report = TealiumReportRequest(message: "Connectivity: Attempting to send queued track call.")
            self.delegate?.tealiumModuleRequests(module: self,
                                                 process: report)
        }
        delegate?.tealiumModuleRequests(module: self, process: req)
    }

    /// Starts monitoring for connectivity changes
    func refreshConnectivityStatus() {
        if let interval = config?.optionalData[TealiumConnectivityKey.refreshIntervalKey] as? Int {
            connectivity.refreshConnectivityStatus(interval)
        } else {
            if config?.optionalData[TealiumConnectivityKey.refreshEnabledKey] as? Bool == false {
                return
            }
            connectivity.refreshConnectivityStatus()
        }
    }

    /// Cancels automatic connectivity checks
    func cancelConnectivityRefresh() {
        connectivity.cancelAutoStatusRefresh()
    }
}
