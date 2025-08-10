//
//  Meditation.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation
//MARK: - Meditation
struct Meditation: Identifiable, Hashable {
    let id: String
    let title: String
    let breathingStyle: BreathingStyle
    let description: String?
    let category: MeditationCategory

    init(id: String, title: String, breathingStyle: BreathingStyle, description: String? = nil, category: MeditationCategory = .mindfulness) {
        self.id = id
        self.title = title
        self.breathingStyle = breathingStyle
        self.description = description
        self.category = category
    }
}

//MARK: - MeditationCategory
enum MeditationCategory: String, CaseIterable {
    case mindfulness = "Mindfulness"
    case breathing = "Breathing"
    case sleep = "Sleep"
    case focus = "Focus"
    case relaxation = "Relaxation"
}

//MARK: - MeditationDuration
public enum MeditationDuration: TimeInterval, CaseIterable, Identifiable {
    case oneMin = 60
    case threeMin = 180
    case fiveMin = 300

    public var id: TimeInterval { rawValue }

    #warning("заміна лейбла (minutes) відповідна до числа")
    var label: String {
        switch self {
        case .oneMin: return "1 min"
        case .threeMin: return "3 min"
        case .fiveMin: return "5 min"
        }
    }
}

//MARK: - MeditationState
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
