//
//  MeditationSession.swift
//  MeditateAndNote
//

import Foundation

public struct SessionID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init() { self.rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UUID.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct SessionDuration: Hashable, Codable, Sendable {
    public let seconds: TimeInterval

    public init(_ duration: MeditationDuration) {
        self.seconds = duration.rawValue
    }

    /// Keep the invariant on the most direct construction path too:
    /// `init(from decoder:)` already rejects non-positive values, so a
    /// programmatic `SessionDuration(seconds: -5)` must not be weaker.
    public init(seconds: TimeInterval) {
        precondition(seconds > 0, "Session duration must be positive")
        self.seconds = seconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(TimeInterval.self)
        guard raw > 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Session duration must be positive"
            )
        }
        self.seconds = raw
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }
}

public struct MeditationSession: Codable, Identifiable, Hashable, Sendable {
    public let id: SessionID
    public let meditationId: MeditationID
    public let completedAt: Date
    public let duration: SessionDuration

    public init(id: SessionID = SessionID(), meditationId: MeditationID, completedAt: Date = .now, duration: SessionDuration) {
        self.id = id
        self.meditationId = meditationId
        self.completedAt = completedAt
        self.duration = duration
    }
}
