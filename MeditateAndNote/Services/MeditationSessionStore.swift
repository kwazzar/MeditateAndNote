//
//  MeditationSessionStore.swift
//  MeditateAndNote
//

import Foundation
import OSLog

@Observable
final class MeditationSessionStore {
    private static let storageKey = "meditationSessions"

    private let logger = Logger(subsystem: Config.bundleID, category: "SessionPersistence")
    private let defaults: UserDefaults

    private(set) var sessions: [MeditationSession]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                sessions = try JSONDecoder().decode([MeditationSession].self, from: data)
            } catch {
                logger.error("Failed to decode stored meditation sessions — \(error.localizedDescription)")
                sessions = []
            }
        } else {
            sessions = []
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
        do {
            let data = try JSONEncoder().encode(sessions)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("Failed to persist meditation sessions — \(error.localizedDescription)")
        }
    }
}
