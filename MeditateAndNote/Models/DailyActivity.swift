//
//  DailyActivity.swift
//  MeditateAndNote
//

import Foundation

/// The four possible states a calendar day can be in with respect to the
/// streak invariant. Streak days are only `.complete` — the other three
/// are partial or empty and never contribute to a streak.
enum CoreDayState: Hashable {
    case empty
    case meditationOnly
    case noteOnly
    case complete

    /// The two states that satisfy the streak invariant.
    static let streakContributing: Set<CoreDayState> = [.complete]

    /// True iff this day is a streak day (both meditation and note present).
    var isStreakDay: Bool { self == .complete }
}

struct DailyActivity: Identifiable, Hashable {
    var id: Date { date }

    let date: Date
    var hasMeditation: Bool
    var hasNote: Bool
    var meditationTime: Date?
    var noteTime: Date?

    var isComplete: Bool { hasMeditation && hasNote }

    /// Derived domain state. The streak engine and UI both consume this
    /// rather than pattern-matching on the two booleans separately.
    var coreDayState: CoreDayState {
        switch (hasMeditation, hasNote) {
        case (true, true): return .complete
        case (true, false): return .meditationOnly
        case (false, true): return .noteOnly
        case (false, false): return .empty
        }
    }

    /// Marks a meditation as completed and records the time atomically.
    /// Without this, callers could set `hasMeditation = true` and forget
    /// `meditationTime`, or vice versa — leaving the entity in a state
    /// the engine can't reason about.
    mutating func markMeditation(at time: Date) {
        hasMeditation = true
        meditationTime = time
    }

    /// Marks a note as created and records the time atomically.
    mutating func markNote(at time: Date) {
        hasNote = true
        noteTime = time
    }
}
