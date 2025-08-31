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
