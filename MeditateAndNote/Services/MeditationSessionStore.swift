//
//  MeditationSessionStore.swift
//  MeditateAndNote
//

import Foundation

@Observable
final class MeditationSessionStore: Sendable {
    private static let storageKey = "meditationSessions"

    private(set) var sessions: [MeditationSession]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([MeditationSession].self, from: data) {
            self.sessions = decoded
        } else {
            self.sessions = []
        }
    }

    func save(_ session: MeditationSession) {
        sessions.append(session)
        persist()
    }

    func sessions(for date: Date) -> [MeditationSession] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }

    func allSessionDates() -> Set<Date> {
        let calendar = Calendar.current
        return Set(sessions.map { calendar.startOfDay(for: $0.completedAt) })
    }

    // MARK: - Private

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
