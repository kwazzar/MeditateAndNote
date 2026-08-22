//
//  Meditation.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation
//MARK: - MeditationID

struct MeditationID: Hashable, Codable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - MeditationTitle

struct MeditationTitle: Hashable, Codable {
    let rawValue: String

    init(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = trimmed.isEmpty ? "Untitled" : trimmed
    }
}

extension MeditationTitle: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self.init(value) }
}

extension MeditationTitle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - Meditation
struct Meditation: Identifiable, Hashable {
    let id: MeditationID
    let title: MeditationTitle
    let breathingStyle: BreathingStyle
    let description: String?
    let category: MeditationCategory

    init(id: MeditationID, title: MeditationTitle, breathingStyle: BreathingStyle, description: String? = nil, category: MeditationCategory = .mindfulness) {
        self.id = id
        self.title = title
        self.breathingStyle = breathingStyle
        self.description = description
        self.category = category
    }
}

enum MeditationError: Error {
    case notFound(id: MeditationID)
}

//MARK: - MeditationCategory
enum MeditationCategory: String, CaseIterable {
    case mindfulness = "Mindfulness"
    case breathing = "Breathing"
    case sleep = "Sleep"
    case focus = "Focus"
    case relaxation = "Relaxation"
}
