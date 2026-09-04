//
//  DailyActivity.swift
//  MeditateAndNote
//

import Foundation

struct DailyActivity: Identifiable, Hashable {
    var id: Date { date }

    let date: Date
    var hasMeditation: Bool
    var hasNote: Bool
    var meditationTime: Date?
    var noteTime: Date?

    var isComplete: Bool { hasMeditation && hasNote }

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
