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
            Meditation(id: "1", title: MeditationTitle("Morning Mindfulness"), breathingStyle: .fourEight, description: "Start your day with awareness", category: .mindfulness),
            Meditation(id: "2", title: MeditationTitle("Deep Breathing"),breathingStyle: .box, description: "Focus on your breath", category: .breathing),
            Meditation(id: "3", title: MeditationTitle("Sleep Preparation"), breathingStyle: .fourSevenEight, description: "Wind down for better sleep", category: .sleep),
            Meditation(id: "4", title: MeditationTitle("Focus Enhancement"), breathingStyle: .fourSevenEight, description: "Improve your concentration", category: .focus),
            Meditation(id: "5", title: MeditationTitle("Stress Relief"), breathingStyle: .box, description: "Let go of tension", category: .relaxation),
            Meditation(id: "6", title: MeditationTitle("Body Scan"), breathingStyle: .fourSevenEight, description: "Connect with your body", category: .mindfulness)
        ]
    }
}
