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

struct MeditationSession: Codable, Identifiable, Hashable {
    let id: SessionID
    let meditationId: MeditationID
    let completedAt: Date
    let duration: TimeInterval

    init(id: SessionID = SessionID(), meditationId: MeditationID, completedAt: Date = .now, duration: TimeInterval) {
        self.id = id
        self.meditationId = meditationId
        self.completedAt = completedAt
        self.duration = duration
    }
}
