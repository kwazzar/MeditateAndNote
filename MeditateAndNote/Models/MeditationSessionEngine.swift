//
//  MeditationSessionEngine.swift
//  MeditateAndNote
//
//  Created by Quasar on 29.08.2026.
//

import Foundation

// MARK: - MeditationSessionEngine

/// Pure state machine for a meditation session. No timers, sound or
/// persistence here — every transition is deterministic given its inputs,
/// and any side effects the caller must perform (play a sound, publish a
/// completion, advance the UI) are returned as `Event`s.
struct MeditationSessionEngine {

    // Remaining time exists only while active, so idle/finished states
    // cannot carry stale progress values.
    enum SessionState {
        case idle
        case countdown(remaining: Int, duration: SessionDuration)
        case active(BreathingClock, duration: SessionDuration, remaining: TimeInterval)
        case finished
    }

    enum Event: Equatable {
        case countdownTick
        case sessionStarted
        case phaseChanged(BreathingPhase)
        case sessionPaused
        case sessionResumed
        case completed(SessionDuration)
    }

    private let pattern: BreathingPattern
    private(set) var state: SessionState = .idle

    init(pattern: BreathingPattern) {
        self.pattern = pattern
    }

    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    var isCountingDown: Bool {
        if case .countdown = state { return true }
        return false
    }

    var isActive: Bool {
        if case .active = state { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    /// Duration currently running when the session is active; nil otherwise.
    var activeDuration: SessionDuration? {
        guard case .active(_, let duration, _) = state else { return nil }
        return duration
    }

    var currentPhase: BreathingPhase? {
        guard case .active(let clock, _, _) = state else { return nil }
        return clock.currentPhase
    }

    var currentPhaseIndex: Int {
        guard case .active(let clock, _, _) = state else { return 0 }
        return clock.phaseIndex
    }

    var countdownRemaining: Int? {
        guard case .countdown(let remaining, _) = state else { return nil }
        return remaining
    }

    var progress: Float {
        guard case .active(_, let duration, let remaining) = state else { return 0 }
        guard duration.seconds > 0 else { return 0 }
        return Float((duration.seconds - remaining) / duration.seconds)
    }

    func phaseProgress(now: Date = Date()) -> Double {
        guard case .active(let clock, _, _) = state else { return 0 }
        return clock.phaseProgress(now: now)
    }

    // MARK: - Transitions

    @discardableResult
    mutating func start(duration: SessionDuration, countdown: Int = 0, now: Date = Date()) -> [Event] {
        if countdown > 0 {
            state = .countdown(remaining: countdown, duration: duration)
            return [.countdownTick]
        } else {
            return beginSession(duration, now: now)
        }
    }

    @discardableResult
    mutating func tickCountdown(now: Date = Date()) -> [Event] {
        guard case .countdown(let remaining, let duration) = state else { return [] }
        if remaining > 1 {
            state = .countdown(remaining: remaining - 1, duration: duration)
            return [.countdownTick]
        } else {
            return beginSession(duration, now: now)
        }
    }

    @discardableResult
    mutating func tickClock(now: Date = Date()) -> [Event] {
        guard case .active(var clock, let duration, let remaining) = state, !clock.isPaused else { return [] }
        let previousPhaseIndex = clock.phaseIndex
        _ = clock.advanceIfPhaseCompleted(now: now)
        var events: [Event] = []
        if clock.phaseIndex != previousPhaseIndex, let phase = clock.currentPhase {
            events.append(.phaseChanged(phase))
        }
        state = .active(clock, duration: duration, remaining: remaining)
        return events
    }

    @discardableResult
    mutating func tickSecond() -> [Event] {
        guard case .active(let clock, let duration, let remaining) = state, !clock.isPaused else { return [] }
        let nextRemaining = remaining - 1
        if nextRemaining > 0 {
            state = .active(clock, duration: duration, remaining: nextRemaining)
            return []
        } else {
            state = .finished
            return [.completed(duration)]
        }
    }

    @discardableResult
    mutating func pause(now: Date = Date()) -> [Event] {
        guard case .active(var clock, let duration, let remaining) = state, !clock.isPaused else { return [] }
        clock.pause(now: now)
        state = .active(clock, duration: duration, remaining: remaining)
        return [.sessionPaused]
    }

    @discardableResult
    mutating func resume(now: Date = Date()) -> [Event] {
        guard case .active(var clock, let duration, let remaining) = state, clock.isPaused else { return [] }
        clock.resume(now: now)
        state = .active(clock, duration: duration, remaining: remaining)
        return [.sessionResumed]
    }

    @discardableResult
    mutating func stop() -> [Event] {
        state = .idle
        return []
    }

    /// Forces the active session into the finished state, emitting the
    /// completion event. Used to drive the UI without waiting for real
    /// timers (tests and user-facing "I'm done" affordances).
    @discardableResult
    mutating func forceComplete(duration: SessionDuration? = nil) -> [Event] {
        guard case .active(_, let activeDuration, _) = state else { return [] }
        let completed = duration ?? activeDuration
        state = .finished
        return [.completed(completed)]
    }

    // MARK: - Private

    private mutating func beginSession(_ duration: SessionDuration, now: Date) -> [Event] {
        let clock = BreathingClock(pattern: pattern, now: now)
        state = .active(clock, duration: duration, remaining: duration.seconds)
        var events: [Event] = [.sessionStarted]
        if let phase = clock.currentPhase {
            events.append(.phaseChanged(phase))
        }
        return events
    }
}