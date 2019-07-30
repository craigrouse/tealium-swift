//
//  TealiumRequests.swift
//  tealium-swift
//
//  Created by Jonathan Wong on 1/10/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//

// Requests are internal notification types used between the modules and
//  modules manager to enable, disable, load, save, delete, and process
//  track data. All request types most conform to the TealiumRequest protocol.
//  The module base class will respond by default to enable, disable, and track
//  but subclasses are expected to override these and/or implement handling of
//  any of the following additional requests or to a module's own custom request
//  type.

/// Request protocol
public protocol TealiumRequest {
    var typeId: String { get set }
    var moduleResponses: [TealiumModuleResponse] { get set }
    var completion: TealiumCompletion? { get set }

    static func instanceTypeId() -> String
}

/// Request to delete persistent data
public struct TealiumDeleteRequest: TealiumRequest {
    public var typeId = TealiumDeleteRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public let name: String

    public init(name: String) {
        self.name = name
        self.completion = nil
    }

    public static func instanceTypeId() -> String {
        return "delete"
    }
}

/// Request to disable.
public struct TealiumDisableRequest: TealiumRequest {
    public var typeId = TealiumDisableRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public init() {}

    public static func instanceTypeId() -> String {
        return "disable"
    }
}

/// Request to enable.
public struct TealiumEnableRequest: TealiumRequest {
    public var typeId = TealiumEnableRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?
    public var enableCompletion: TealiumEnableCompletion?
    public let config: TealiumConfig

    public init(config: TealiumConfig, enableCompletion: TealiumEnableCompletion?) {
        self.config = config
        self.enableCompletion = enableCompletion
    }

    public static func instanceTypeId() -> String {
        return "enable"
    }
}

/// Request to load persistent data.
public struct TealiumLoadRequest: TealiumRequest {
    public var typeId = TealiumLoadRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?
    public let name: String

    public init(name: String,
                completion: TealiumCompletion?) {
        self.name = name
        self.completion = completion
    }

    public static func instanceTypeId() -> String {
        return "load"
    }
}

// Module wants to report status to any listening modules
public struct TealiumReportRequest: TealiumRequest {
    public var typeId = TealiumReportNotificationsRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public let message: String

    public init(message: String) {
        self.message = message
    }

    public static func instanceTypeId() -> String {
        return "report"
    }
}

// Module requests to be notified of any reports or when all modules finished
//  processing a request.
public struct TealiumReportNotificationsRequest: TealiumRequest {
    public var typeId = TealiumReportNotificationsRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public init() {
    }

    public static func instanceTypeId() -> String {
        return "reportnotification"
    }
}

/// Request to send any queued data.
public struct TealiumReleaseQueuesRequest: TealiumRequest {
    public var typeId = TealiumReleaseQueuesRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public init(typeId: String, moduleResponses: [TealiumModuleResponse], completion: TealiumCompletion?) {
        self.typeId = typeId
        self.moduleResponses = moduleResponses
        self.completion = completion
    }

    public static func instanceTypeId() -> String {
        return "queuerelease"
    }
}

/// Request to queue a track call
public struct TealiumEnqueueRequest: TealiumRequest {
    public var typeId = TealiumEnqueueRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?
    public let data: [TealiumTrackRequest]

    public init(data: TealiumTrackRequest,
                completion: TealiumCompletion?) {
        self.data = [data]
        self.completion = completion
    }

    public init(data: TealiumBatchTrackRequest,
                completion: TealiumCompletion?) {
        self.data = data.trackRequests
        self.completion = completion
    }

    public static func instanceTypeId() -> String {
        return "enqueue"
    }
}

/// Request to send any queued data.
public struct TealiumClearQueuesRequest: TealiumRequest {
    public var typeId = TealiumClearQueuesRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public init(typeId: String, moduleResponses: [TealiumModuleResponse], completion: TealiumCompletion?) {
        self.typeId = typeId
        self.moduleResponses = moduleResponses
        self.completion = completion
    }

    public static func instanceTypeId() -> String {
        return "queuedelete"
    }
}

/// Request to save persistent data.
public struct TealiumSaveRequest: TealiumRequest {
    public var typeId = TealiumSaveRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?
    public var requestingModule: String?

    public let name: String
    public let data: [String: Any]

    public init(name: String,
                data: [String: Any]) {
        self.name = name
        self.data = data
        self.completion = nil
    }

    public static func instanceTypeId() -> String {
        return "save"
    }
}

/// Request to deliver data.
public struct TealiumTrackRequest: TealiumRequest, Codable {
    public var typeId = TealiumTrackRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public var data: AnyEncodable

    public var trackDictionary: [String: Any] {
        if let data = data.value as? [String: Any] {
            return data
        }
        return ["": ""]
    }

    enum CodingKeys: String, CodingKey {
        case typeId
        case data
    }

    public init(data: [String: Any],
                completion: TealiumCompletion?) {
        self.data = data.encodable
        self.completion = completion
    }

    public static func instanceTypeId() -> String {
        return "track"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeId, forKey: .typeId)
        try container.encode(data, forKey: .data)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try values.decode(AnyDecodable.self, forKey: .data)

        data = AnyEncodable(decoded.value as? [String: Any])
        typeId = try values.decode(String.self, forKey: .typeId)
    }

    public mutating func deleteKey(_ key: String) {
        var dictionary = self.trackDictionary
        dictionary.removeValue(forKey: key)
        self.data = dictionary.encodable
    }

    public func event() -> String? {
        return self.trackDictionary[TealiumKey.event] as? String
    }

}

public struct TealiumBatchTrackRequest: TealiumRequest, Codable {
    public var typeId = TealiumTrackRequest.instanceTypeId()
    let sharedKeys = [TealiumKey.account,
                      TealiumKey.profile,
                      TealiumKey.dataSource,
                      TealiumKey.libraryName,
                      TealiumKey.libraryVersion,
                      TealiumKey.uuid,
                      TealiumKey.device,
                      TealiumKey.simpleModel,
                      TealiumKey.architectureLegacy,
                      TealiumKey.architecture,
                      TealiumKey.cpuType,
                      TealiumKey.cpuTypeLegacy,
                      TealiumKey.language,
                      TealiumKey.languageLegacy,
                      TealiumKey.resolution,
                      TealiumKey.platform,
                      TealiumKey.osName,
                      TealiumKey.fullModel,
                      TealiumKey.visitorId
    ]
    public var trackRequests: [TealiumTrackRequest]

    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    enum CodingKeys: String, CodingKey {
        case typeId
        case trackRequests
    }

    public static func instanceTypeId() -> String {
        return "batchtrack"
    }

    public init(trackRequests: [TealiumTrackRequest],
                completion: TealiumCompletion?) {
        self.trackRequests = trackRequests
        self.completion = completion
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        trackRequests = try values.decode([TealiumTrackRequest].self, forKey: CodingKeys.trackRequests)
        typeId = try values.decode(String.self, forKey: .typeId)
    }

    /// returns: `[String: Any]?` containing the batched payload with shared keys extracted into `shared` object ``
    /// Eventual JSON structure:`{"events":[{"somekey":"somevalue"}, "shared":{"somesharedkey":"somesharedvalue"}}`
    public func compressed() -> [String: Any]? {
        var events = [[String: Any]]()
        guard let firstRequest = trackRequests.first else {
            return nil
        }

        let shared = extractSharedKeys(from: firstRequest.trackDictionary)

        for request in trackRequests {
            let newRequest = request.trackDictionary.filter { !sharedKeys.contains($0.key) }
            events.append(newRequest)
        }

        return ["events": events, "shared": shared]
    }

    func extractSharedKeys(from dictionary: [String: Any]) -> [String: Any] {
        var newSharedDictionary = [String: Any]()

        sharedKeys.forEach { key in
            if dictionary[key] != nil {
                newSharedDictionary[key] = dictionary[key]
            }
        }

        return newSharedDictionary
    }

}

public struct TealiumDeviceDataRequest: TealiumRequest {
    public var typeId = TealiumDeviceDataRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public static func instanceTypeId() -> String {
        return "devicedata"
    }
}

public struct TealiumJoinTraceRequest: TealiumRequest {
    public var typeId = TealiumJoinTraceRequest.instanceTypeId()
    public var traceId: String
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public static func instanceTypeId() -> String {
        return "jointrace"
    }

    public init(traceId: String) {
        self.traceId = traceId
    }

}

public struct TealiumLeaveTraceRequest: TealiumRequest {
    public var typeId = TealiumLeaveTraceRequest.instanceTypeId()
    public var moduleResponses = [TealiumModuleResponse]()
    public var completion: TealiumCompletion?

    public static func instanceTypeId() -> String {
        return "leavetrace"
    }

    public init () {}
}
