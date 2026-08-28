//
//  MeditationSession.swift
//  MeditateAndNote
//

import Foundation

struct SessionID: Hashable, Codable {
    let rawValue: UUID

    init() { self.rawValue = UUID() }
    init(rawValue: UUID) { self.rawValue = rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UUID.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct SessionDuration: Hashable, Codable {
    let seconds: TimeInterval

    init(_ duration: MeditationDuration) {
        self.seconds = duration.rawValue
    }

    /// Keep the invariant on the most direct construction path too:
    /// `init(from decoder:)` already rejects non-positive values, so a
    /// programmatic `SessionDuration(seconds: -5)` must not be weaker.
    init(seconds: TimeInterval) {
        precondition(seconds > 0, "Session duration must be positive")
        self.seconds = seconds
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(seconds)
    }
}

struct MeditationSession: Codable, Identifiable, Hashable {
    let id: SessionID
    let meditationId: MeditationID
    let completedAt: Date
    let duration: SessionDuration

    init(id: SessionID = SessionID(), meditationId: MeditationID, completedAt: Date = .now, duration: SessionDuration) {
        self.id = id
        self.meditationId = meditationId
        self.completedAt = completedAt
        self.duration = duration
    }
}
