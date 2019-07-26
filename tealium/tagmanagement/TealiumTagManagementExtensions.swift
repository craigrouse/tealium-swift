//
//  TealiumTagManagementExtensions.swift
//  tealium-swift
//
//  Created by Craig Rouse on 07/03/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation
import UIKit
#if tagmanagement
import TealiumCore
#endif

// MARK: EXTENSIONS

public extension TealiumConfig {

    /// Sets the default queue size for the Tag Management module. This queue is active until the webview has finished loading.
    ///
    /// - parameter queueSize: Int representing the maximum queue size for Tag Management module requests
    func setTagManagementQueueSize(queueSize: Int) {
        optionalData[TealiumTagManagementConfigKey.maxQueueSize] = queueSize
    }

    /// Adds optional delegates to the WebView instance
    ///
    /// - parameter delegates: Array of delegates, downcast from AnyObject due to different delegate APIs for UIWebView and WKWebView. Expected to be one of UIWebViewDelegate or WKNavigationDelegate
    func setWebViewDelegates(_ delegates: [AnyObject]) {
        optionalData[TealiumTagManagementConfigKey.delegate] = delegates
    }

    /// Gets array of optional webview delegates from the Config instance
    ///
    /// - returns: Array of AnyObject, representing either a UIWebViewDelegate or WKNavigationDelegate
    func getWebViewDelegates() -> [AnyObject]? {
        return optionalData[TealiumTagManagementConfigKey.delegate] as? [AnyObject]
    }

    /// Optional override for the tag management webview URL
    ///
    /// - parameter string: String representing the URL to be loaded by the webview. Must be a valid URL
    func setTagManagementOverrideURL(string: String) {
        optionalData[TealiumTagManagementConfigKey.overrideURL] = string
    }

    /// Optional override to force the legacy UIWebView to be used instead of WKWebView
    ///
    /// - parameter useLegacyWebview: Bool (true if legacy webview should be used)
    func setShouldUseLegacyWebview(shouldUse: Bool) {
        optionalData[TealiumTagManagementConfigKey.shouldUseLegacyWebview] = shouldUse
    }

    /// Checks for config override for legacy UIWebView
    ///
    /// - returns: Bool (true if legacy webview should be used)
    func getShouldUseLegacyWebview() -> Bool {
        return optionalData[TealiumTagManagementConfigKey.shouldUseLegacyWebview] as? Bool ?? false
    }

    /// Gets the URL to be loaded by the webview (mobile.html)
    ///
    /// - returns: A URL representing either the custom URL provided in the TealiumConfig object, or the default Tealium mCDN URL
    func webviewURL() -> URL? {
        if let overrideWebviewURL = self.optionalData[TealiumTagManagementConfigKey.overrideURL] as? String {
            return URL(string: overrideWebviewURL)
        } else {
            return URL(string: "\(TealiumTagManagementKey.defaultUrlStringPrefix)/\(self.account)/\(self.profile)/\(self.environment)/mobile.html")
        }
    }

    /// Sets a root view for WKWebView to be attached to. Only required for complex view hierarchies.
    ///
    /// - parameter view: UIView instance for WKWebView to be attached to
    func setRootView(_ view: UIView) {
        optionalData[TealiumTagManagementConfigKey.uiview] = view
    }

    /// Checks if a specific root view has been provided in the TealiumConfig instance.
    ///
    /// - returns: Optional UIView to be used.
    func getRootView() -> UIView? {
        return optionalData[TealiumTagManagementConfigKey.uiview] as? UIView
    }
//    
//    func setTagManagementRefreshInterval(minutes: Float) {
//        
//    }
//    
//    func getTagMangementRefreshInterval() -> Float {
//        guard let self.optionalData
//    }

}

#if TEST
#else
public extension Tealium {

    /// Returns an instance of the Tag Management _webview_ instance (WKWebView for iOS11+, UIWebView for iOS <11)
    ///
    /// - returns: TealiumTagManagementProtocol (WKWebView for iOS11+, UIWebView for iOS <11)
    func tagManagement() -> TealiumTagManagementProtocol? {
        guard let module = modulesManager.getModule(forName: TealiumTagManagementKey.moduleName) as? TealiumTagManagementModule else {
            return nil
        }

        return module.tagManagement
    }

    func updateRootView(_ view: UIView) {
        self.tagManagement()?.setRootView(view, completion: nil)
    }
}
#endif
