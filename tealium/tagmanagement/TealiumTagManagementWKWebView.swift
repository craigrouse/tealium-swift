//
//  TealiumTagManagementWKWebView.swift
//  tealium-swift
//
//  Created by Craig Rouse on 06/12/2018.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation
import UIKit
import WebKit
#if tagmanagement
import TealiumCore
#endif

public enum WebViewState: Int {
    case isLoaded = 0
    case isLoading = 1
    case didFailToLoad = 2
    case notYetLoaded = 3
}

@available(iOS 11.0, *)
public class TealiumTagManagementWKWebView: NSObject, TealiumTagManagementProtocol {

    var webview: WKWebView?
    var webviewConfig: WKWebViewConfiguration?
    var webviewDidFinishLoading = false
    var enableCompletion: ((_ success: Bool, _ error: Error?) -> Void)?
    // current view being used for WKWebView
    weak var view: UIView?
    var url: URL?
    var reloading = false
    var reloadHandler: TealiumCompletion?
    var currentState: AtomicInteger = AtomicInteger(value: WebViewState.notYetLoaded.rawValue) {
        willSet {
            // TODO: Make this use the core logger
            if let state = WebViewState(rawValue: newValue.value) {
                    print("Webview state changed to: \(state)")
            }
        }
    }

    public var delegates = TealiumMulticastDelegate<WKNavigationDelegate>()

    /// Enables the webview. Called by the webview module at init time.
    ///
    /// - Parameters:
    /// - webviewURL: The URL (typically for "mobile.html") to be loaded by the webview
    /// - shouldMigrateCookies: Indicates whether cookies should be migrated from HTTPCookieStore (UIWebView)
    /// - completion: completion block to be called when the webview has finished loading
    public func enable(webviewURL: URL?,
                       shouldMigrateCookies: Bool,
                       delegates: [AnyObject]?,
                       view: UIView?,
                       completion: ((_ success: Bool, _ error: Error?) -> Void)?) {
        if webview != nil {
            // webview already enabled
            return
        }
        if let delegates = delegates {
            setWebViewDelegates(delegates)
        }
        enableCompletion = completion
        self.url = webviewURL
        setupWebview(forURL: webviewURL, withSpecificView: view)
    }

    /// Sets a root view for WKWebView to be attached to. Only required for complex view hierarchies.
    ///
    /// - parameter view: UIView instance for WKWebView to be attached to
    public func setRootView(_ view: UIView,
                            completion: ((_ success: Bool) -> Void)?) {
        self.view = view
        // forward success/failure to optional completion
        self.attachToUIView(specificView: view) { success in
            completion?(success)
        }
    }

    /// Adds optional delegates to the WebView instance
    ///
    /// - parameter delegates: Array of delegates, downcast from AnyObject due to different delegate APIs for UIWebView and WKWebView
    public func setWebViewDelegates(_ delegates: [AnyObject]) {
        delegates.forEach { delegate in
            if let delegate = delegate as? WKNavigationDelegate {
                self.delegates.add(delegate)
            }
        }
    }

    /// Removes optional delegates for the WebView instance
    ///
    /// - parameter delegates: Array of delegates, downcast from AnyObject due to different delegate APIs for UIWebView and WKWebView
    public func removeWebViewDelegates(_ delegates: [AnyObject]) {
        delegates.forEach { delegate in
            if let delegate = delegate as? WKNavigationDelegate {
                self.delegates.remove(delegate)
            }
        }
    }

    /// Configures an instance of WKWebView for later use.
    ///
    /// - parameter forURL: The URL (typically for mobile.html) to load in the webview
    func setupWebview(forURL url: URL?, withSpecificView specificView: UIView?) {
        // required to force cookies to sync
        WKWebsiteDataStore.default().httpCookieStore.add(self)
        let config = WKWebViewConfiguration()
        self.webview = WKWebView(frame: .zero, configuration: config)
        webview?.navigationDelegate = self
        guard let webview = webview else {
            self.enableCompletion?(false, TealiumWebviewError.webviewNotInitialized)
            return
        }

        // attach the webview to the view before continuing
        attachToUIView(specificView: specificView) { _ in
            migrateCookies(forWebView: webview) {
                guard let url = url else {
                    self.enableCompletion?(false, TealiumWebviewError.webviewURLMissing)
                    return
                }
                let request = URLRequest(url: url)
                DispatchQueue.main.async {
                    webview.load(request)
                }
            }
        }
    }

    public func reload(_ completion: @escaping (Bool, [String: Any]?, Error?) -> Void) {
        guard let url = url else {
            return
        }
        self.reloading = true
        self.reloadHandler = completion
        let request = URLRequest(url: url)
        DispatchQueue.main.async {
            self.currentState = AtomicInteger(value: WebViewState.isLoading.rawValue)
            self.webview?.load(request)
        }
    }

    /// Internal webview status check.
    /// - returns: Bool indicating whether or not the internal webview is ready for dispatching.
    public func isWebViewReady() -> Bool {
        guard webview != nil else {
            return false
        }
        return WebViewState(rawValue: currentState.value) == WebViewState.isLoaded
    }

    /// Process event data for UTAG delivery.
    ///
    /// - Parameters:
    /// - data: [String:Any] Dictionary of preferably String or [String] values.
    /// - completion: Optional completion handler to call when call completes.
    public func track(_ data: [String: Any], completion: ((Bool, [String: Any], Error?) -> Void)?) {
        guard let javascriptString = data.tealiumJavaScriptTrackCall else {
            completion?(false,
                        ["original_payload": data, "sanitized_payload": data],
                        TealiumTagManagementError.couldNotJSONEncodeData)
            return
        }
        DispatchQueue.main.async {
            // always re-attach to UIView. If specific view has been previously passed in, this will be used.
            // nil is passed to force attachToUIView to auto-detect and check for a valid view, since this track call could be happening after the view was dismissed
            self.attachToUIView(specificView: nil) { _ in }
        }

        var info = [String: Any]()
        info[TealiumKey.dispatchService] = TealiumTagManagementKey.moduleName
        info[TealiumTagManagementKey.jsCommand] = javascriptString
        info += [TealiumTagManagementKey.payload: data]
        self.evaluateJavascript(javascriptString) { result in
            info += result
            completion?(true, info, nil)
        }
    }

    public func trackMultiple(_ data: [[String: Any]],
                              completion: ((Bool, [String: Any], Error?) -> Void)?) {

        let totalSuccesses = AtomicInteger(value: 0)

        data.forEach {
            self.track($0) { success, _, _ in
                if success {
                    _ = totalSuccesses.incrementAndGet()
                } else {
                    _ = totalSuccesses.decrementAndGet()
                }
            }
        }

        let allCallsSuccessful = totalSuccesses.value == data.count

        completion?(allCallsSuccessful, ["": ""], nil)

    }

    /// Handles JavaScript evaluation on the WKWebView instance
    ///
    /// - Parameters:
    /// - jsString: The JavaScript call to be executed in the webview
    /// - completion: Optional completion block to be called after the JavaScript call completes
    public func evaluateJavascript (_ jsString: String, _ completion: (([String: Any]) -> Void)?) {
        // webview js evaluation must be on main thread
        var info = [String: Any]()
        DispatchQueue.main.async {
            if self.webview?.superview == nil {
                self.attachToUIView(specificView: nil) { _ in }
            }
            self.webview?.evaluateJavaScript(jsString) { result, error in
                if let result = result {
                    info += [TealiumTagManagementKey.jsResult: result]
                }

                if let error = error {
                    info += [TealiumTagManagementKey.jsError: error]
                }
            }
        }
        completion?(info)
    }

    /// Called by the WKWebView delegate when the page finishes loading
    ///
    /// - parameter state: The webview state after the state change
    public func webviewStateDidChange(_ state: TealiumWebViewState, withError error: Error?) {
        switch state {
        case .loadSuccess:
            self.currentState = AtomicInteger(value: WebViewState.isLoaded.rawValue)
            if let reloadHandler = self.reloadHandler {
                self.webviewDidFinishLoading = true
                self.reloading = false
                reloadHandler(true, nil, nil)
                self.reloadHandler = nil
            } else {
                guard webviewDidFinishLoading == false else {
                    return
                }
                webviewDidFinishLoading = true

                self.enableCompletion?(true, nil)
            }
        case .loadFailure:
            self.currentState = AtomicInteger(value: WebViewState.didFailToLoad.rawValue)
            if let reloadHandler = self.reloadHandler {
                self.webviewDidFinishLoading = true
                self.reloading = false
                reloadHandler(false, nil, error)
                self.reloadHandler = nil
            } else {
                self.enableCompletion?(false, error)
            }
        }
    }

    /// Called when the module needs to disable the webview
    public func disable() {
        webview?.stopLoading()
        webview = nil
    }

    deinit {
        webview?.stopLoading()
        webview?.navigationDelegate = nil
        webview = nil
    }
}
