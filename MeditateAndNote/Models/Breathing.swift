//
//  Breathing.swift
//  MeditateAndNote
//
//  Created by Quasar on 05.08.2025.
//

import Foundation
//MARK: - BreathingPattern
struct BreathingPattern {
    let name: String
    let phases: [BreathingPhase]
}

//MARK: - BreathingPhaseType
enum BreathingPhaseType: String {
    case inhale      = "Inhale"
    case holdAfterInhale = "Hold"
    case exhale      = "Exhale"
    case holdAfterExhale = "Hold After Exhale"
}

//MARK: - BreathingPhase
struct BreathingPhase: Identifiable {
    let id = UUID()
    let type: BreathingPhaseType
    let duration: TimeInterval
}

//MARK: - BreathingStyle
enum BreathingStyle: String, CaseIterable, Identifiable {
    case fourSevenEight = "4-7-8"
    case box = "Box"
    case fourEight = "4-8"
    case custom = "Custom"

    var id: String { rawValue }

    var pattern: BreathingPattern {
        switch self {
        case .fourSevenEight:
            return BreathingPattern(
                name: "4-7-8",
                phases: [
                    .init(type: .inhale, duration: 4),
                    .init(type: .holdAfterInhale, duration: 7),
                    .init(type: .exhale, duration: 8)
                ]
            )
        case .box:
            return BreathingPattern(
                name: "Box Breathing",
                phases: [
                    .init(type: .inhale, duration: 4),
                    .init(type: .holdAfterInhale, duration: 4),
                    .init(type: .exhale, duration: 4),
                    .init(type: .holdAfterExhale, duration: 4)
                ]
            )
        case .fourEight:
            return BreathingPattern(
                name: "4-8",
                phases: [
                    .init(type: .inhale, duration: 4),
                    .init(type: .exhale, duration: 8)
                ]
            )
        case .custom:
            return BreathingPattern(name: "Custom", phases: [])
        }
    }
}
