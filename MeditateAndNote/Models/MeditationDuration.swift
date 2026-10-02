//
//  MeditationDuration.swift
//  MeditateAndNote
//

import Foundation

// MARK: - MeditationState

enum MeditationState {
    case notStarted
    case started
    case paused
    case finished
}

// MARK: - MeditationDuration
public enum MeditationDuration: TimeInterval, CaseIterable, Identifiable, Sendable {
    case oneMin = 60
    case threeMin = 180
    case fiveMin = 300

    public var id: TimeInterval { rawValue }
}
