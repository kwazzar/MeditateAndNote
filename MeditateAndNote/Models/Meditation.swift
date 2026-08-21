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

//MARK: - MeditationCore (pure domain logic)

struct MeditationCore {
    let meditation: Meditation

    var meditationTitle: String {
        meditation.title.rawValue
    }

    func progress(totalDuration: TimeInterval, currentTime: TimeInterval) -> Float {
        guard totalDuration > 0 else { return 0 }
        return Float((totalDuration - currentTime) / totalDuration)
    }

    func minutes(from duration: TimeInterval) -> Int {
        Int(duration / 60)
    }

    func label(for duration: TimeInterval) -> String {
        let measurement = Measurement(value: Double(minutes(from: duration)), unit: UnitDuration.minutes)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current
        return formatter.string(from: measurement)
    }

    func nextPhase(after index: Int, in pattern: BreathingPattern) -> (index: Int, phase: BreathingPhase, cycleCountIncreased: Bool)? {
        let phases = pattern.phases
        guard !phases.isEmpty else { return nil }

        let newIndex = (index + 1) % phases.count
        return (newIndex, phases[newIndex], newIndex == 0)
    }
}
