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
            return BreathingPattern(
                name: "Custom",
                phases: [
                    .init(type: .inhale, duration: 4),
                    .init(type: .exhale, duration: 4)
                ]
            )
        }
    }
}

//MARK: - BreathingClock

struct BreathingClock {
    enum RunState {
        case running(phaseStart: Date)
        case paused(elapsed: TimeInterval)
    }

    let pattern: BreathingPattern
    private(set) var phaseIndex: Int
    private(set) var runState: RunState

    var isPaused: Bool {
        if case .paused = runState { return true }
        return false
    }

    init(pattern: BreathingPattern) {
        self.pattern = pattern
        self.phaseIndex = 0
        self.runState = .running(phaseStart: Date())
    }

    var currentPhase: BreathingPhase? {
        pattern.phases.indices.contains(phaseIndex) ? pattern.phases[phaseIndex] : nil
    }

    mutating func pause(now: Date = Date()) {
        if case let .running(phaseStart) = runState {
            runState = .paused(elapsed: now.timeIntervalSince(phaseStart))
        }
    }

    mutating func resume(now: Date = Date()) {
        if case let .paused(elapsed) = runState {
            runState = .running(phaseStart: now.addingTimeInterval(-elapsed))
        }
    }

    func phaseProgress(now: Date = Date()) -> Double {
        guard let phase = currentPhase else { return 0 }
        let elapsed: TimeInterval
        switch runState {
        case let .running(phaseStart):
            elapsed = now.timeIntervalSince(phaseStart)
        case let .paused(frozen):
            elapsed = frozen
        }
        return min(max(elapsed / phase.duration, 0), 1)
    }

    mutating func advanceIfPhaseCompleted(now: Date = Date()) -> Bool {
        guard phaseProgress(now: now) >= 1 else { return false }
        phaseIndex = (phaseIndex + 1) % max(pattern.phases.count, 1)
        runState = .running(phaseStart: now)
        return phaseIndex == 0
    }
}
