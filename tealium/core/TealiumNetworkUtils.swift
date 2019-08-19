//
//  TealiumNetworkUtils.swift
//  tealium-swift
//
//  Created by Craig Rouse on 11/02/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

import Foundation

public func jsonStringWithDictionary(_ dictionary: [String: Any]) -> String? {
    var writingOptions: JSONEncoder.OutputFormatting

    if #available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *) {
        writingOptions = [.prettyPrinted, .sortedKeys]
    } else {
        writingOptions = [.prettyPrinted]
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = writingOptions
    let coded = dictionary.encodable
    if let jsonData = try? encoder.encode(coded) {
        return String(data: jsonData, encoding: .utf8)
    } else {
        return nil
    }
}

public func jsonStringWithArray(_ array: [[String: Any]]) -> String? {
    var writingOptions: JSONEncoder.OutputFormatting

    if #available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *) {
        writingOptions = [.prettyPrinted, .sortedKeys]
    } else {
        writingOptions = [.prettyPrinted]
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = writingOptions
//    let coded = dictionary.encodable
    let coded = AnyEncodable(array)
    if let jsonData = try? encoder.encode(coded) {
        return String(data: jsonData, encoding: .utf8)
    } else {
        return nil
    }
}

public func urlPOSTRequestWithJSONString(_ jsonString: String, dispatchURL: String) -> URLRequest? {
    if let dispatchURL = URL(string: dispatchURL) {
        var request = URLRequest(url: dispatchURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        if let data = try? jsonString.data(using: .utf8)?.gzipped(level: .bestCompression) {
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            request.httpBody = data
        } else {
            request.httpBody = jsonString.data(using: .utf8)
        }
//        request.httpBody = jsonString.data(using: .utf8)
        return request
    }
    return nil
}

public extension Dictionary {
    func toJSONString() -> String? {
        var writingOptions: JSONSerialization.WritingOptions
        if #available(iOS 11.0, tvOS 11.0, watchOS 4.0, OSX 10.13, *) {
            writingOptions = [.prettyPrinted, .sortedKeys]
        } else {
            writingOptions = [.prettyPrinted]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: self, options: writingOptions) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
}
