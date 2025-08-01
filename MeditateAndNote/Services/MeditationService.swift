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
            Meditation(id: "1", title: "Morning Mindfulness", duration: 600, description: "Start your day with awareness", category: .mindfulness),
            Meditation(id: "2", title: "Deep Breathing", duration: 300, description: "Focus on your breath", category: .breathing),
            Meditation(id: "3", title: "Sleep Preparation", duration: 900, description: "Wind down for better sleep", category: .sleep),
            Meditation(id: "4", title: "Focus Enhancement", duration: 720, description: "Improve your concentration", category: .focus),
            Meditation(id: "5", title: "Stress Relief", duration: 480, description: "Let go of tension", category: .relaxation),
            Meditation(id: "6", title: "Body Scan", duration: 840, description: "Connect with your body", category: .mindfulness)
        ]
    }
}
