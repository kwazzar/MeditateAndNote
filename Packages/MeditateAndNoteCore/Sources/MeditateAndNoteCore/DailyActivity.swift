//
//  DailyActivity.swift
//  MeditateAndNote
//

import Foundation

/// The four possible states a calendar day can be in with respect to the
/// streak invariant. Streak days are only `.complete` — the other three
/// are partial or empty and never contribute to a streak.
public enum CoreDayState: Hashable, Sendable {
    case empty
    case meditationOnly
    case noteOnly
    case complete

    /// The two states that satisfy the streak invariant.
    public static let streakContributing: Set<CoreDayState> = [.complete]

    /// True iff this day is a streak day (both meditation and note present).
    public var isStreakDay: Bool { self == .complete }
}

public struct DailyActivity: Identifiable, Hashable {
    public var id: Date { date }

    public let date: Date
    public var hasMeditation: Bool
    public var hasNote: Bool
    public var meditationTime: Date?
    public var noteTime: Date?

    public init(
        date: Date,
        hasMeditation: Bool,
        hasNote: Bool,
        meditationTime: Date? = nil,
        noteTime: Date? = nil
    ) {
        self.date = date
        self.hasMeditation = hasMeditation
        self.hasNote = hasNote
        self.meditationTime = meditationTime
        self.noteTime = noteTime
    }

    public var isComplete: Bool { hasMeditation && hasNote }

    /// Derived domain state. The streak engine and UI both consume this
    /// rather than pattern-matching on the two booleans separately.
    public var coreDayState: CoreDayState {
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
    public mutating func markMeditation(at time: Date) {
        hasMeditation = true
        meditationTime = time
    }

    /// Marks a note as created and records the time atomically.
    public mutating func markNote(at time: Date) {
        hasNote = true
        noteTime = time
    }
}
