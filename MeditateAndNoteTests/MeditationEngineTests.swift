//
//  MeditationEngineTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 29.08.2026.
//

import XCTest
@testable import MeditateAndNote

final class MeditationEngineTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// 1s inhale + 1s exhale — keeps the math trivial in tests.
    private var tickPattern: BreathingPattern {
        BreathingPattern(name: "Tick", phases: [
            BreathingPhase(type: .inhale, duration: 1),
            BreathingPhase(type: .exhale, duration: 1)
        ])
    }

    private func makeEngine() -> MeditationSessionEngine {
        MeditationSessionEngine(pattern: tickPattern)
    }

    private func sec(_ value: TimeInterval) -> SessionDuration {
        SessionDuration(seconds: value)
    }

    // MARK: - Countdown

    func testCountdownTicksThenStarts() {
        var engine = makeEngine()

        XCTAssertEqual(engine.start(duration: sec(60), countdown: 3, now: base), [.countdownTick])
        XCTAssertTrue(engine.isCountingDown)
        XCTAssertEqual(engine.countdownRemaining, 3)

        XCTAssertEqual(engine.tickCountdown(), [.countdownTick])
        XCTAssertEqual(engine.countdownRemaining, 2)

        XCTAssertEqual(engine.tickCountdown(), [.countdownTick])
        XCTAssertEqual(engine.countdownRemaining, 1)

        let final = engine.tickCountdown()
        XCTAssertEqual(final,
                       [.sessionStarted, .phaseChanged(BreathingPhase(type: .inhale, duration: 1))])
        XCTAssertTrue(engine.isActive)
        XCTAssertNil(engine.countdownRemaining)
    }

    func testCountdownTickIdlesInFinishedStateDoesNothing() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        XCTAssertEqual(engine.tickCountdown(), [], "tickCountdown outside countdown is a no-op")
    }

    // MARK: - Start

    func testStartWithoutCountdownStartsSessionImmediately() {
        var engine = makeEngine()

        let events = engine.start(duration: sec(60), countdown: 0, now: base)
        XCTAssertEqual(events,
                       [.sessionStarted, .phaseChanged(BreathingPhase(type: .inhale, duration: 1))])
        XCTAssertTrue(engine.isActive)
        XCTAssertEqual(engine.currentPhaseIndex, 0)
        XCTAssertEqual(engine.progress, 0)
    }

    // MARK: - Second counting

    func testTickSecondDecrementsProgress() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(3), countdown: 0, now: base)

        _ = engine.tickSecond(now: base.addingTimeInterval(1))
        XCTAssertEqual(engine.progress, Float(1.0 / 3.0), accuracy: 0.0001)

        _ = engine.tickSecond(now: base.addingTimeInterval(2))
        XCTAssertEqual(engine.progress, Float(2.0 / 3.0), accuracy: 0.0001)
    }

    // MARK: - Finishing (complete the in-flight phase, don't cut it off)

    func testTimeOutDoesNotCutOffMidPhase() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(1), countdown: 0, now: base)

        // Budget runs out while phase 0 (1s inhale) is still breathing.
        let events = engine.tickSecond(now: base.addingTimeInterval(1))
        XCTAssertEqual(events, [], "No completion event yet — the current breath must round out first")
        XCTAssertFalse(engine.isFinished, "Session must stay active until an exhale completes")
        XCTAssertEqual(engine.progress, 1.0, accuracy: 0.0001)

        // Completing the in-flight inhale advances to exhale, but does not finish.
        _ = engine.tickClock(now: base.addingTimeInterval(1))
        XCTAssertFalse(engine.isFinished, "Don't finish on an inhale — wait for the exhale")

        // Completing the exhale closes the session.
        let closing = engine.tickClock(now: base.addingTimeInterval(2))
        XCTAssertTrue(engine.isFinished)
        XCTAssertTrue(closing.contains(.completed(sec(1))))
    }

    func testFinishingKeepsBreathingUntilExhaleEnds() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(1), countdown: 0, now: base)

        _ = engine.tickSecond(now: base.addingTimeInterval(1)) // → finishing

        // Mid-phase clock tick does not finish yet; breathing continues.
        let mid = engine.tickClock(now: base.addingTimeInterval(0.5))
        XCTAssertFalse(engine.isFinished)
        XCTAssertFalse(mid.contains(where: { if case .completed = $0 { return true }; return false }))

        // Inhale rounds out → exhale; still not finished (finishing on exhale only).
        _ = engine.tickClock(now: base.addingTimeInterval(1))
        XCTAssertFalse(engine.isFinished)

        // Exhale ends → session finishes.
        let end = engine.tickClock(now: base.addingTimeInterval(2))
        XCTAssertTrue(engine.isFinished)
        XCTAssertTrue(end.contains(.completed(sec(1))))
    }

    func testFinishingOnExhaleWhenExhaleWasInflight() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(3), countdown: 0, now: base)

        // Advance to the exhale phase (phase 1) with plenty of time left.
        _ = engine.tickClock(now: base.addingTimeInterval(1)) // inhale 1s done → exhale
        XCTAssertEqual(engine.currentPhase?.type, .exhale)

        // Time runs out while on the exhale — it completes and finishes at once.
        _ = engine.tickSecond(now: base.addingTimeInterval(1 + 1)) // 2s elapsed of 3 → remaining 1
        _ = engine.tickSecond(now: base.addingTimeInterval(3))     // budget done → finishing
        XCTAssertFalse(engine.isFinished)

        let closing = engine.tickClock(now: base.addingTimeInterval(3)) // exhale ends
        XCTAssertTrue(engine.isFinished)
        XCTAssertTrue(closing.contains(.completed(sec(3))))
    }

    // MARK: - Wall-clock alignment

    func testTickSecondUsesRealElapsedTime_notCountingTicks() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        // A single late tick (e.g. timer coalescing or backgrounding) jumps the
        // full real elapsed time instead of subtracting just one tick (1s).
        _ = engine.tickSecond(now: base.addingTimeInterval(5))
        XCTAssertEqual(engine.progress, Float(5.0 / 60.0), accuracy: 0.0001)
    }

    func testPauseFreezesCountdownAndResumeReanchors() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        _ = engine.tickSecond(now: base.addingTimeInterval(5))
        XCTAssertEqual(engine.progress, Float(5.0 / 60.0), accuracy: 0.0001)

        // Pause freezes remaining at the pause moment.
        _ = engine.pause(now: base.addingTimeInterval(5))
        // While paused, a long wall-clock gap must not consume the countdown.
        _ = engine.tickSecond(now: base.addingTimeInterval(100))
        XCTAssertEqual(engine.progress, Float(5.0 / 60.0), accuracy: 0.0001)

        // Resume re-anchors; only post-resume time is counted.
        _ = engine.resume(now: base.addingTimeInterval(100))
        _ = engine.tickSecond(now: base.addingTimeInterval(103))
        XCTAssertEqual(engine.progress, Float(8.0 / 60.0), accuracy: 0.0001)
    }

    // MARK: - Phase clock

    func testTickClockAdvancesPhasesAndWraps() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)
        XCTAssertEqual(engine.currentPhaseIndex, 0)

        // inhale (1s) completed → exhale
        _ = engine.tickClock(now: base.addingTimeInterval(1))
        XCTAssertEqual(engine.currentPhaseIndex, 1)
        XCTAssertEqual(engine.currentPhase, BreathingPhase(type: .exhale, duration: 1))

        // exhale (1s) completed → wraps back to inhale
        _ = engine.tickClock(now: base.addingTimeInterval(2))
        XCTAssertEqual(engine.currentPhaseIndex, 0)
        XCTAssertEqual(engine.currentPhase, BreathingPhase(type: .inhale, duration: 1))
    }

    func testTickClockEmitsPhaseChangedOnlyOnTransition() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        XCTAssertEqual(engine.tickClock(now: base.addingTimeInterval(0.5)), [], "mid-phase tick emits nothing")
        XCTAssertEqual(engine.tickClock(now: base.addingTimeInterval(1)),
                       [.phaseChanged(BreathingPhase(type: .exhale, duration: 1))])
    }

    // MARK: - Pause / resume

    func testPauseFreezesProgressAndResumePreservesElapsed() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        XCTAssertEqual(engine.pause(now: base.addingTimeInterval(0.5)), [.sessionPaused])
        XCTAssertEqual(engine.phaseProgress(now: base.addingTimeInterval(0.5)), 0.5, accuracy: 0.0001)

        // Advancing "now" while paused must not move progress.
        XCTAssertEqual(engine.phaseProgress(now: base.addingTimeInterval(50)), 0.5, accuracy: 0.0001)

        XCTAssertEqual(engine.resume(now: base.addingTimeInterval(30)), [.sessionResumed])
        XCTAssertEqual(engine.phaseProgress(now: base.addingTimeInterval(30.3)), 0.8, accuracy: 0.0001)
    }

    func testPausedSessionIgnoresTicks() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(3), countdown: 0, now: base)
        _ = engine.pause(now: base.addingTimeInterval(0.5))

        XCTAssertEqual(engine.tickClock(now: base.addingTimeInterval(50)), [])
        XCTAssertEqual(engine.tickSecond(now: base.addingTimeInterval(50)), [])
        XCTAssertEqual(engine.currentPhaseIndex, 0)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.phaseProgress(now: base.addingTimeInterval(50)), 0.5, accuracy: 0.0001)
    }

    func testDoublePauseAndResumeAreNoops() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 0, now: base)

        XCTAssertEqual(engine.pause(now: base), [.sessionPaused])
        XCTAssertEqual(engine.pause(now: base), [])
        XCTAssertEqual(engine.resume(now: base), [.sessionResumed])
        XCTAssertEqual(engine.resume(now: base), [])
    }

    // MARK: - Stop

    func testStopResetsToIdle() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(60), countdown: 3, now: base)

        XCTAssertEqual(engine.stop(), [])
        XCTAssertTrue(engine.isIdle)
        XCTAssertNil(engine.countdownRemaining)
        XCTAssertNil(engine.currentPhase)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.phaseProgress(), 0)
    }

    // MARK: - State invariants

    func testFinishedStateCarriesNoStaleProgress() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(1), countdown: 0, now: base)

        // Time out, then finish once an exhale completes.
        _ = engine.tickSecond(now: base.addingTimeInterval(1)) // → finishing
        _ = engine.tickClock(now: base.addingTimeInterval(1))  // inhale → exhale
        _ = engine.tickClock(now: base.addingTimeInterval(2))  // exhale ends → finished
        XCTAssertTrue(engine.isFinished)
        XCTAssertNil(engine.currentPhase)
        XCTAssertNil(engine.countdownRemaining)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.phaseProgress(), 0)
    }
}