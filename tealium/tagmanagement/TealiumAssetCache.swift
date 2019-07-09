////
////  TealiumAssetCache.swift
////  tealium-swift
////
////  Created by Craig Rouse on 04/07/2019.
////  Copyright © 2019 Tealium, Inc. All rights reserved.
////
//
//import Foundation
//
//class TealiumAssetCache {
////    var diskStorage = TealiumDiskStorage(config: TealiumConfig(account: "tealiummobile", profile: "demo", environment: "dev"), forModule: "tagmanagement")
//    init() {
//        self.getUtagFile(baseUrl: "https://tags.tiqcdn.com", account: "tealiummobile", profile: "demo", env: "dev")
//    }
//
//    func getUtagFile(baseUrl: String,
//                     account: String,
//                     profile: String,
//                     env: String) {
//
//        let url = URL(string: "\(baseUrl)/utag/\(account)/\(profile)/\(env)")
//        guard let utagURL = url?.appendingPathComponent("utag.js") else {
//            return
//        }
//
//        guard let mobileHTML = url?.appendingPathComponent("mobile.html") else {
//            return
//        }
//         data, urlresponse, error in...
//        URLSession.shared.dataTask(with: utagURL) { abc, def, ghi in
//            print("hello")
//            try? Disk.save(abc!, to: .caches, as: "tealiummobile.demo/tagmanagement/utag.js")
//            print("\(abc)\(def)\(ghi)")
//        }.resume()
//
//        URLSession.shared.dataTask(with: mobileHTML) { abc, def, ghi in
//            print("hello")
//            try? Disk.save(abc!, to: .caches, as: "tealiummobile.demo/tagmanagement/mobile.html")
//            if let publishSettings = self.getPublishSettings(from: abc!) {
//                try? Disk.save(publishSettings.encodable, to: .caches, as: "tealiummobile.demo/core/publishsetttings")
//            }
//            print("\(abc)\(def)\(ghi)")
//        }.resume()
//
//    }
//
//    func getPublishSettings(from data: Data) -> [String: Any]? {
//        guard let dataString = String(data: data, encoding: .utf8) else {
//            return nil
//        }
//
//        let endScript = dataString.range(of: "</script>")
//        let startScript = dataString.range(of: "var mps = ")
//
//        let string = dataString[..<endScript!.lowerBound]
//        let newSubString = string[startScript!.upperBound...]
//
//        guard let data = newSubString.data(using: .utf8) else {
//            return nil
//        }
//
//        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//
//}
//
//}
