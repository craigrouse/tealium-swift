//
//  TealiumQueues.swift
//  tealium-swift
//
//  Created by Craig Rouse on 27/06/2019.
//  Copyright © 2019 Tealium, Inc. All rights reserved.
//

import Foundation

class TealiumQueues {

    public static let backgroundConcurrentQueue = {
        return ReadWrite("com.tealium.backgroundconcurrentqueue")
    }()

    static let mainQueue = DispatchQueue.main

    static let backgroundSerialQueue = DispatchQueue(label: "com.tealium.backgroundserialqueue", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: .global(qos: .background))
}
