//
//  MeditationService.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

protocol MeditationService {
    func getMeditations() -> [Meditation]
}

final class SampleMeditationService: MeditationService {
    func getMeditations() -> [Meditation] {
        return [
            Meditation(id: "1", title: MeditationTitle("Morning Mindfulness"), breathingStyle: .fourEight, description: "Start your day with awareness and presence. This gentle session helps wake up the mind and body, grounding you in the here and now.", category: .mindfulness),
            Meditation(id: "2", title: MeditationTitle("Deep Breathing"),breathingStyle: .box, description: "Focus on your breath with a steady box pattern. Calm your nervous system and reset your attention with this simple, powerful technique.", category: .breathing),
            Meditation(id: "3", title: MeditationTitle("Sleep Preparation"), breathingStyle: .fourSevenEight, description: "Wind down for better sleep with a deeply relaxing rhythm. This practice eases tension and guides your body toward a peaceful rest.", category: .sleep),
            Meditation(id: "4", title: MeditationTitle("Focus Enhancement"), breathingStyle: .fourSevenEight, description: "Improve your concentration and mental clarity. This session trains your attention and helps you stay fully engaged in the task at hand.", category: .focus),
            Meditation(id: "5", title: MeditationTitle("Stress Relief"), breathingStyle: .box, description: "Let go of tension and find your calm. A balanced breathing practice that brings you back to center even in the midst of a busy day.", category: .relaxation),
            Meditation(id: "6", title: MeditationTitle("Body Scan"), breathingStyle: .fourSevenEight, description: "Connect with your body from head to toe. Slowly notice each sensation and release the tension you have been carrying all day long.", category: .mindfulness)
        ]
    }
}

// MARK: - MeditationSelectionStore

final class MeditationSelectionStore {
    private static let storageKey = "lastSelectedMeditationId"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSelectedID: MeditationID? {
        get { defaults.string(forKey: Self.storageKey).map(MeditationID.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.storageKey)
            } else {
                defaults.removeObject(forKey: Self.storageKey)
            }
        }
    }
}
