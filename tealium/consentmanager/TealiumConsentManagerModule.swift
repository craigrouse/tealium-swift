//
//  TealiumConsentManagerModule.swift
//  tealium-swift
//
//  Created by Craig Rouse on 3/29/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation
#if consentmanager
import TealiumCore
#endif

class TealiumConsentManagerModule: TealiumModule {

    let consentManager = TealiumConsentManager()
    var ready: Bool = false

    override class func moduleConfig() -> TealiumModuleConfig {
        return  TealiumModuleConfig(name: TealiumConsentConstants.moduleName,
                                    priority: 975,
                                    build: 2,
                                    enabled: true)
    }

    /// Enables the module and starts the Consent Manager instance
    ///
    /// - parameter request: `TealiumEnableRequest` - the request from the core library to enable this module
    override func enable(_ request: TealiumEnableRequest) {
        isEnabled = true
        // start consent manager with completion block
        consentManager.start(config: request.config, delegate: delegate) {
            self.ready = true
            self.releaseQueue()
            self.didFinish(request)
        }
        consentManager.addConsentDelegate(self)
    }

    override func handle(_ request: TealiumRequest) {
        switch request {
        case let request as TealiumEnableRequest:
            enable(request)
        case let request as TealiumTrackRequest:
            track(request)
        case let request as TealiumBatchTrackRequest:
            batchTrack(request)
        case let request as TealiumDisableRequest:
            disable(request)
        default:
            didFinish(request)
        }
    }

    func batchTrack(_ request: TealiumBatchTrackRequest) {
        guard isEnabled == true else {
            didFinishWithNoResponse(request)
            return
        }

        // note: consent events are excluded from batching, so do not need to handle special case, as with the standard track call

        var allRequests = request.trackRequests

        allRequests = allRequests.map {
            addConsentDataToTrack($0)
        }

        let newTrack = TealiumBatchTrackRequest(trackRequests: allRequests, completion: request.completion)

        // if not ready yet, queue requests
        if !ready {
            queue(newTrack)
            let report = TealiumReportRequest(message: "Consent Manager: Queued track. Consent Manager not ready.")
            delegate?.tealiumModuleRequests(module: self,
                                            process: report)
            return
        }

        // check if tracking is allowed
        switch consentManager.getTrackingStatus() {
        case .trackingQueued:
            queue(newTrack)
//            consentManager.willQueueTrackingCall(newTrack)
        // yes, user has allowed tracking
        case .trackingAllowed:
//            consentManager.willSendTrackingCall(newTrack)
            didFinishWithNoResponse(newTrack)
        // user declined tracking. we will discard this request
        case .trackingForbidden:
            self.purgeQueue()
//            consentManager.willDropTrackingCall(newTrack)
            return
        }

    }

    /// Decides whether a tracking request can be completed based on current consent status.
    ///
    /// - parameter track: `TealiumTrackRequest` to be considered for processing.
    override func track(_ track: TealiumTrackRequest) {

        // do nothing if disabled - return to normal operation
        guard isEnabled == true else {
            didFinishWithNoResponse(track)
            return
        }

        // allow tracking calls to continue if they are for auditing purposes
        if let event = track.trackDictionary[TealiumKey.event] as? String, (event == TealiumConsentConstants.consentPartialEventName
                || event == TealiumConsentConstants.consentGrantedEventName || event == TealiumConsentConstants.consentDeclinedEventName || event == TealiumKey.updateConsentCookieEventName) {
            didFinishWithNoResponse(track)
            return
        }

        // append consent data to each tracking request
        let newTrack = addConsentDataToTrack(track)

        // if not ready yet, queue requests
        guard ready else {
            queue(newTrack)
            let report = TealiumReportRequest(message: "Consent Manager: Queued track. Consent Manager not ready.")
            delegate?.tealiumModuleRequests(module: self,
                                            process: report)
            return
        }

        // check if tracking is allowed
        switch consentManager.getTrackingStatus() {
        case .trackingQueued:
            queue(newTrack)
            consentManager.willQueueTrackingCall(newTrack)
                // yes, user has allowed tracking
        case .trackingAllowed:
            consentManager.willSendTrackingCall(newTrack)
            didFinishWithNoResponse(newTrack)
                // user declined tracking. we will discard this request
        case .trackingForbidden:
            self.purgeQueue()
            consentManager.willDropTrackingCall(newTrack)
            return
        }
    }

    /// Adds consent categories and status to the tracking request.
    ///
    /// - parameter track: `TealiumTrackRequest` to be modified.
    func addConsentDataToTrack(_ track: TealiumTrackRequest) -> TealiumTrackRequest {
        var newTrack = track.trackDictionary
        if let consentDictionary = consentManager.getUserConsentPreferences()?.toDictionary() {
            newTrack.merge(consentDictionary) { _, new -> Any in
                new
            }
        }

        return TealiumTrackRequest(data: newTrack, completion: track.completion)
    }

    /// Queues a tracking request until consent status is known.
    ///
    /// - parameter track: `TealiumTrackRequest` to be queued.
    func queue(_ track: TealiumTrackRequest) {
        var newData = track.trackDictionary
        newData[TealiumKey.queueReason] = TealiumConsentConstants.moduleName
        let newTrack = TealiumTrackRequest(data: newData,
                                           completion: track.completion)
        let req = TealiumEnqueueRequest(data: newTrack, completion: nil)
        self.delegate?.tealiumModuleRequests(module: self, process: req)
    }

    func queue(_ track: TealiumBatchTrackRequest) {
        track.trackRequests.forEach {
            queue($0)
        }
    }

    /// Releases all queued tracking calls. Called if tracking consent is granted by the user.
    func releaseQueue() {
        // queue will be released, but will only be allowed to continue if tracking is allowed when track call is resubmitted
        let req = TealiumReleaseQueuesRequest(typeId: "consent", moduleResponses: [TealiumModuleResponse]()) { _, _, _ in
            let report = TealiumReportRequest(message: "Consent Manager: Attempting to send queued track call.")
            self.delegate?.tealiumModuleRequests(module: self,
                                                 process: report)
        }
        self.delegate?.tealiumModuleRequests(module: self, process: req)
    }

    /// Clears all pending dispatches from the DispatchQueue. Called if tracking consent is declined by the user.
    func purgeQueue() {
        let req = TealiumClearQueuesRequest(typeId: "consent", moduleResponses: [TealiumModuleResponse]()) { _, _, _ in
            let report = TealiumReportRequest(message: "Consent Manager: Purging queue.")
            self.delegate?.tealiumModuleRequests(module: self,
                                                 process: report)
        }
        self.delegate?.tealiumModuleRequests(module: self, process: req)
    }

    /// Disables the Consent Manager module
    ///
    /// - parameter request: `TealiumDisableRequest`
    override func disable(_ request: TealiumDisableRequest) {
        isEnabled = false
        didFinish(request)
    }
}
