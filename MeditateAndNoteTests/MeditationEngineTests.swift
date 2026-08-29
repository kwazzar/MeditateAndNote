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

    func testTickSecondDecrementsProgressAndCompletes() {
        var engine = makeEngine()
        _ = engine.start(duration: sec(3), countdown: 0, now: base)

        _ = engine.tickSecond()
        XCTAssertEqual(engine.progress, Float(1.0 / 3.0), accuracy: 0.0001)

        _ = engine.tickSecond()
        XCTAssertEqual(engine.progress, Float(2.0 / 3.0), accuracy: 0.0001)

        let final = engine.tickSecond()
        XCTAssertEqual(final, [.completed(sec(3))])
        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.progress, 0)
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
        XCTAssertEqual(engine.tickSecond(), [])
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

        _ = engine.tickSecond()
        XCTAssertTrue(engine.isFinished)
        XCTAssertNil(engine.currentPhase)
        XCTAssertNil(engine.countdownRemaining)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertEqual(engine.phaseProgress(), 0)
    }
}