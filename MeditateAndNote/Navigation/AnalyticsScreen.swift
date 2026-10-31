//
//  AnalyticsScreen.swift
//  MeditateAndNote
//

import Foundation

/// Stable screen names for `screen_view`. Never include note/book IDs.
extension TabDestination {
    var analyticsScreenName: String { rawValue }
}

extension PushDestination {
    var analyticsScreenName: String {
        switch self {
        case .newNote: return "note_editor"
        case .noteDetails: return "note_details"
        case .meditation: return "meditation"
        case .meditationCompletion: return "meditation_completion"
        case .streakDetail: return "streak_detail"
        case .settings: return "settings"
        }
    }
}

extension SheetDestination {
    var analyticsScreenName: String {
        switch self {
        case .newNote: return "note_editor"
        case .meditationSettings: return "meditation_settings"
        case .timeMeditation: return "time_meditation"
        }
    }
}

extension FullScreenDestination {
    var analyticsScreenName: String {
        switch self {
        case .meditationSession: return "meditation_session"
        case .fullScreenNote: return "note_editor"
        case .reader: return "reader"
        }
    }
}
