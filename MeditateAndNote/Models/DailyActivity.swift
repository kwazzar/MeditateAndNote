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
}
