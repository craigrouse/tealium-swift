//
//  TealiumCollectPostDispatcher.swift
//  tealium-swift
//
//  Created by Craig Rouse on 11/31/18.
//  Copyright © 2017 Tealium, Inc. All rights reserved.
//

import Foundation
#if collect
import TealiumCore
#endif

class TealiumCollectPostDispatcher: TealiumCollectProtocol {

    var urlSession: URLSession?
    var urlSessionConfiguration: URLSessionConfiguration?
//    var dispatchURL: String
    static var defaultDispatchBaseURL = "https://collect.tealiumiq.com"
    static var singleEventPath = "/event/"
    static var bulkEventPath = "/bulk-event/"

    var bulkEventDispatchURL: String?
    var singleEventDispatchURL: String?
    // hello
    /// hello
    /// Initializes dispatcher
    ///
    /// - Parameters:
    /// - dispatchURL: String representation of the dispatch URL
    /// - completion: Completion handler to run when the dispatcher has finished initializing
    init(dispatchURL: String,
         _ completion: @escaping ((_ dispatcher: TealiumCollectPostDispatcher?) -> Void)) {
            if let baseURL = TealiumCollectPostDispatcher.getDomainFromURLString(url: dispatchURL) {
                self.bulkEventDispatchURL = "https://\(baseURL)\(TealiumCollectPostDispatcher.bulkEventPath)"
                self.singleEventDispatchURL = "https://\(baseURL)\(TealiumCollectPostDispatcher.singleEventPath)"
            } else {
                self.bulkEventDispatchURL = "\(TealiumCollectPostDispatcher.defaultDispatchBaseURL)\(TealiumCollectPostDispatcher.bulkEventPath)"
                self.singleEventDispatchURL = "\(TealiumCollectPostDispatcher.defaultDispatchBaseURL)\(TealiumCollectPostDispatcher.singleEventPath)"
            }
        self.setupURLSession {
            // pass instance of self for use in unit tests
            completion(self)
        }
    }

    static func getDomainFromURLString(url: String) -> String? {
        guard let url = URL(string: url) else {
            return nil
        }

        return url.host
    }

    /// Sets up the URL session object for later use
    ///
    /// - parameter completion: Optional completion to be called when session setup is complete
    func setupURLSession(_ completion: (() -> Void)?) {
        self.urlSessionConfiguration = URLSessionConfiguration.default
        if let urlSessionConfiguration = self.urlSessionConfiguration {
            self.urlSession = URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
        }
        completion?()
    }

    /// Dispatches data to an HTTP endpoint, then calls optional completion block when finished
    ///
    /// - Parameters:
    /// - data: [String:Any] of variables to be dispatched
    /// - completion: Optional completion block to be called when operation complete
    func dispatch(data: [String: Any],
                  completion: TealiumCompletion?) {
        if let jsonString = jsonStringWithDictionary(data), let url = singleEventDispatchURL, let urlRequest = urlPOSTRequestWithJSONString(jsonString, dispatchURL: url) {
            sendURLRequest(urlRequest, completion)
        } else {
            completion?(false, nil, TealiumCollectError.noDataToTrack)
        }
    }

    func dispatchBulk(data: [String: Any],
                      completion: TealiumCompletion?) {
        if let jsonString = jsonStringWithDictionary(data), let url = bulkEventDispatchURL, let urlRequest = urlPOSTRequestWithJSONString(jsonString, dispatchURL: url) {
            sendURLRequest(urlRequest, completion)
        } else {
            completion?(false, nil, TealiumCollectError.noDataToTrack)
        }
    }

    /// Sends a URLRequest, then calls the completion handler, passing success/failures back to the completion handler
    ///
    /// - Parameters:
    /// - request: URLRequest object
    /// - completion: Optional completion block to handle success/failure
    func sendURLRequest(_ request: URLRequest, _ completion: TealiumCompletion?) {
        if let urlSession = self.urlSession {
            let task = urlSession.dataTask(with: request) { _, response, error in
                if let error = error {
                    completion?(false, nil, error)
                } else if let status = response as? HTTPURLResponse {
                    // error only indicates "no response from server. 400 responses are considered successful
                    if let errorHeader = status.allHeaderFields[TealiumCollectKey.errorHeaderKey] as? String {
                        completion?(false, ["error": errorHeader], TealiumCollectError.xErrorDetected)
                    } else if status.statusCode != 200 {
                        completion?(false, nil, TealiumCollectError.non200Response)
                    } else {
                        completion?(true, nil, nil)
                    }
                }
            }
            task.resume()
        }
    }

    deinit {
        urlSessionConfiguration = nil
        urlSession?.finishTasksAndInvalidate()
        urlSession = nil
    }

}
