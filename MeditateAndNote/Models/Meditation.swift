//
//  Meditation.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

struct Meditation: Identifiable, Hashable {
    let id: String
    let title: String
    let duration: TimeInterval
    let description: String?
    let category: MeditationCategory

    init(id: String, title: String, duration: TimeInterval, description: String? = nil, category: MeditationCategory = .mindfulness) {
        self.id = id
        self.title = title
        self.duration = duration
        self.description = description
        self.category = category
    }
}

enum MeditationCategory: String, CaseIterable {
    case mindfulness = "Mindfulness"
    case breathing = "Breathing"
    case sleep = "Sleep"
    case focus = "Focus"
    case relaxation = "Relaxation"
}
