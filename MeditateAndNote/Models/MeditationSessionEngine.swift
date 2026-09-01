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
        /// `remaining` is the time left as of `anchoredAt`. Deriving it from a
        /// wall-clock anchor (rather than counting timer ticks) keeps the
        /// session aligned to real elapsed time: timer drift, coalescing or a
        /// backgrounded app can no longer make the meditation overrun.
        ///
        /// `finishing` is set once the allotted time has elapsed but the current
        /// breathing phase has not yet completed. While finishing, the countdown
        /// stays at 0 and the clock keeps running. The session transitions to
        /// `.finished` when an exhale phase rounds out, so a slow-arriving timer
        /// never cuts off a half-finished breath or ends on a held inhale.
        case active(BreathingClock, duration: SessionDuration, remaining: TimeInterval, anchoredAt: Date, finishing: Bool)
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
        guard case .active(_, let duration, _, _, _) = state else { return nil }
        return duration
    }

    var currentPhase: BreathingPhase? {
        guard case .active(let clock, _, _, _, _) = state else { return nil }
        return clock.currentPhase
    }

    var currentPhaseIndex: Int {
        guard case .active(let clock, _, _, _, _) = state else { return 0 }
        return clock.phaseIndex
    }

    var countdownRemaining: Int? {
        guard case .countdown(let remaining, _) = state else { return nil }
        return remaining
    }

    var progress: Float {
        guard case .active(_, let duration, let remaining, _, _) = state else { return 0 }
        guard duration.seconds > 0 else { return 0 }
        return Float((duration.seconds - remaining) / duration.seconds)
    }

    func phaseProgress(now: Date = Date()) -> Double {
        guard case .active(let clock, _, _, _, _) = state else { return 0 }
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
        guard case .active(var clock, let duration, let remaining, let anchoredAt, let finishing) = state, !clock.isPaused else { return [] }
        let previousPhaseIndex = clock.phaseIndex
        let wasExhale = clock.currentPhase?.type == .exhale
        _ = clock.advanceIfPhaseCompleted(now: now)
        let phaseCompleted = clock.phaseIndex != previousPhaseIndex
        var events: [Event] = []
        if phaseCompleted, let phase = clock.currentPhase {
            events.append(.phaseChanged(phase))
        }
        // Once the time has elapsed (finishing), close the session as soon as
        // an exhale rounds out — never mid-inhale/hold and not on a random
        // phase. Ramping down on the breath-out feels natural and avoids a
        // held breath right at the end.
        if finishing, wasExhale, phaseCompleted {
            state = .finished
            events.append(.completed(duration))
            return events
        }
        state = .active(clock, duration: duration, remaining: remaining, anchoredAt: anchoredAt, finishing: finishing)
        return events
    }

    @discardableResult
    mutating func tickSecond(now: Date = Date()) -> [Event] {
        guard case .active(let clock, let duration, let remaining, let anchoredAt, let finishing) = state, !clock.isPaused else { return [] }
        if finishing { return [] }
        // Recompute from the wall-clock anchor instead of blindly subtracting
        // 1: if a timer was coalesced or the app was backgrounded, the real
        // elapsed time is larger than one tick, so the countdown stays aligned
        // to wall-clock time.
        let elapsed = now.timeIntervalSince(anchoredAt)
        let nextRemaining = max(remaining - elapsed, 0)
        if nextRemaining > 0 {
            state = .active(clock, duration: duration, remaining: nextRemaining, anchoredAt: now, finishing: false)
            return []
        } else {
            // Time budget is exhausted, but keep breathing until the current
            // phase completes (see tickClock) instead of hard-cutting it off.
            state = .active(clock, duration: duration, remaining: 0, anchoredAt: now, finishing: true)
            return []
        }
    }

    @discardableResult
    mutating func pause(now: Date = Date()) -> [Event] {
        guard case .active(var clock, let duration, let remaining, _, let finishing) = state, !clock.isPaused else { return [] }
        clock.pause(now: now)
        // Anchor to now so the frozen remaining does not drift while paused.
        state = .active(clock, duration: duration, remaining: remaining, anchoredAt: now, finishing: finishing)
        return [.sessionPaused]
    }

    @discardableResult
    mutating func resume(now: Date = Date()) -> [Event] {
        guard case .active(var clock, let duration, let remaining, _, let finishing) = state, clock.isPaused else { return [] }
        clock.resume(now: now)
        // Re-anchor so time counting resumes from this moment, not from before
        // the pause.
        state = .active(clock, duration: duration, remaining: remaining, anchoredAt: now, finishing: finishing)
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
        guard case .active(_, let activeDuration, _, _, _) = state else { return [] }
        let completed = duration ?? activeDuration
        state = .finished
        return [.completed(completed)]
    }

    // MARK: - Private

    private mutating func beginSession(_ duration: SessionDuration, now: Date) -> [Event] {
        let clock = BreathingClock(pattern: pattern, now: now)
        state = .active(clock, duration: duration, remaining: duration.seconds, anchoredAt: now, finishing: false)
        var events: [Event] = [.sessionStarted]
        if let phase = clock.currentPhase {
            events.append(.phaseChanged(phase))
        }
        return events
    }
}