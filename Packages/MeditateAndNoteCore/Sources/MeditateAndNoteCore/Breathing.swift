//
//  Breathing.swift
//  MeditateAndNote
//
//  Created by Quasar on 05.08.2025.
//

import Foundation
//MARK: - BreathingPattern
public struct BreathingPattern {
    public let name: String
    public let phases: [BreathingPhase]

    public init(
        name: String,
        phases: [BreathingPhase]
    ) {
        self.name = name
        self.phases = phases
    }
}

//MARK: - BreathingPhaseType
public enum BreathingPhaseType: String {
    case inhale
    case holdAfterInhale
    case exhale
    case holdAfterExhale
}

//MARK: - BreathingPhase
public struct BreathingPhase: Identifiable, Equatable {
    public var id: String { type.rawValue }

    public let type: BreathingPhaseType
    public let duration: TimeInterval

    public init(
        type: BreathingPhaseType,
        duration: TimeInterval
    ) {
        self.type = type
        self.duration = duration
    }
}

//MARK: - BreathingStyle
public enum BreathingStyle: String, CaseIterable, Identifiable, Sendable {
    case fourSevenEight = "4-7-8"
    case box = "Box"
    case fourEight = "4-8"
    case custom = "Custom"

    public var id: String { rawValue }

    public var pattern: BreathingPattern {
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

public struct BreathingClock {
    public enum RunState {
        case running(phaseStart: Date)
        case paused(elapsed: TimeInterval)
    }

    public let pattern: BreathingPattern
    public private(set) var phaseIndex: Int
    public private(set) var runState: RunState

    public var isPaused: Bool {
        if case .paused = runState { return true }
        return false
    }

    public init(pattern: BreathingPattern, now: Date = Date()) {
        self.pattern = pattern
        self.phaseIndex = 0
        self.runState = .running(phaseStart: now)
    }

    public var currentPhase: BreathingPhase? {
        pattern.phases.indices.contains(phaseIndex) ? pattern.phases[phaseIndex] : nil
    }

    public mutating func pause(now: Date = Date()) {
        if case let .running(phaseStart) = runState {
            runState = .paused(elapsed: now.timeIntervalSince(phaseStart))
        }
    }

    public mutating func resume(now: Date = Date()) {
        if case let .paused(elapsed) = runState {
            runState = .running(phaseStart: now.addingTimeInterval(-elapsed))
        }
    }

    public func phaseProgress(now: Date = Date()) -> Double {
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

    public mutating func advanceIfPhaseCompleted(now: Date = Date()) -> Bool {
        guard phaseProgress(now: now) >= 1 else { return false }
        phaseIndex = (phaseIndex + 1) % max(pattern.phases.count, 1)
        runState = .running(phaseStart: now)
        return phaseIndex == 0
    }
}
