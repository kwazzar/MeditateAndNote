//
//  MeditationSession.swift
//  MeditateAndNote
//

import Foundation

struct MeditationSession: Codable, Identifiable, Hashable {
    let id: UUID
    let meditationId: String
    let completedAt: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), meditationId: String, completedAt: Date = .now, duration: TimeInterval) {
        self.id = id
        self.meditationId = meditationId
        self.completedAt = completedAt
        self.duration = duration
    }
}
