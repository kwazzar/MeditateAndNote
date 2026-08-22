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

    var progressText: String {
        switch self {
        case .notStarted:
            return "Start"
        case .started:
            return "Tap to Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Next"
        }
    }
}

// MARK: - MeditationDuration
public enum MeditationDuration: TimeInterval, CaseIterable, Identifiable {
    case oneMin = 60
    case threeMin = 180
    case fiveMin = 300

    public var id: TimeInterval { rawValue }

    var minutes: Int {
        Int(rawValue / 60)
    }

    var label: String {
        let measurement = Measurement(value: Double(minutes), unit: UnitDuration.minutes)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current
        return formatter.string(from: measurement)
    }
}
