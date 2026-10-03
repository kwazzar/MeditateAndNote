//
//  Meditation.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation
//MARK: - MeditationID

public struct MeditationID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - MeditationTitle

public struct MeditationTitle: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = trimmed.isEmpty ? "Untitled" : trimmed
    }
}

extension MeditationTitle: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}

public extension MeditationTitle {
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
public struct Meditation: Identifiable, Hashable, Sendable {
    public let id: MeditationID
    public let title: MeditationTitle
    public let breathingStyle: BreathingStyle
    public let description: String?
    public let category: MeditationCategory

    public init(id: MeditationID, title: MeditationTitle, breathingStyle: BreathingStyle, description: String? = nil, category: MeditationCategory = .mindfulness) {
        self.id = id
        self.title = title
        self.breathingStyle = breathingStyle
        self.description = description
        self.category = category
    }
}

public enum MeditationError: Error {
    case notFound(id: MeditationID)
}

//MARK: - MeditationCategory
public enum MeditationCategory: String, CaseIterable, Sendable {
    case mindfulness = "Mindfulness"
    case breathing = "Breathing"
    case sleep = "Sleep"
    case focus = "Focus"
    case relaxation = "Relaxation"
}
