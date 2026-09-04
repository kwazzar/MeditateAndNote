//
//  MeditationViewModelTests.swift
//  MeditateAndNoteTests
//

import XCTest
@testable import MeditateAndNote

@MainActor
final class MeditationViewModelTests: XCTestCase {

    private var bus: DomainEventBus!
    private var capture: MeditationEventCapture!
    private var sound: FakeSoundPlayer!

    override func setUp() {
        super.setUp()
        bus = DomainEventBus()
        capture = MeditationEventCapture(bus: bus)
        sound = FakeSoundPlayer()
    }

    override func tearDown() {
        bus = nil
        capture = nil
        sound = nil
        super.tearDown()
    }

    private func makeMeditation() -> Meditation {
        Meditation(
            id: "test",
            title: MeditationTitle("Test Breath"),
            breathingStyle: .box
        )
    }

    private func makeSUT() -> MeditationViewModel {
        MeditationViewModel(
            meditation: makeMeditation(),
            eventBus: bus,
            soundPlayer: sound
        )
    }

    // MARK: - completedDuration

    func testCompletedDuration_isNilBeforeCompletion() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)
        XCTAssertNil(vm.completedDuration, "Duration is unknown until the session finishes")
    }

    func testCompletedDuration_isSetOnCompletion() throws {
        let vm = makeSUT()
        vm.start(with: .fiveMin, countdown: 0)

        let advanced = vm.advanceToCompletion()
        XCTAssertTrue(advanced)
        XCTAssertEqual(vm.completedDuration, .fiveMin)
        XCTAssertEqual(vm.meditationState, .finished)
    }

    func testCompletedDuration_mapsChosenPreset() {
        let vm = makeSUT()
        vm.start(with: .threeMin, countdown: 0)
        _ = vm.advanceToCompletion()

        XCTAssertEqual(vm.completedDuration, .threeMin, "Completion carries the duration the session was started with")
    }

    // MARK: - Domain event + sound on completion

    func testCompletion_publishesMeditationCompletedEvent() throws {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        _ = vm.advanceToCompletion()

        XCTAssertEqual(capture.completedCount, 1, "A completed meditation must publish exactly one event")
    }

    func testCompletion_publishesEventWithMeditationAndDuration() throws {
        let vm = makeSUT()
        vm.start(with: .threeMin, countdown: 0)

        _ = vm.advanceToCompletion()

        guard let event = capture.events.first(where: {
            if case .meditationCompleted = $0 { return true }
            return false
        }) else {
            XCTFail("Expected a meditationCompleted event")
            return
        }

        guard case let .meditationCompleted(session) = event else {
            XCTFail("Unexpected event")
            return
        }
        XCTAssertEqual(session.meditationId, MeditationID(rawValue: "test"))
        XCTAssertEqual(session.duration, SessionDuration(.threeMin))
    }

    func testCompletion_playsFinishedSound() throws {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        _ = vm.advanceToCompletion()

        XCTAssertTrue(sound.played.contains(.finished), "Finished sound must play on completion")
    }

    func testNoCompletion_doesNotPublishEventOrPlayFinished() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)
        vm.pause()

        XCTAssertEqual(capture.completedCount, 0)
        XCTAssertFalse(sound.played.contains(.finished))
    }

    // MARK: - advanceToCompletion guard

    func testAdvanceToCompletion_returnsFalseWhenIdle() {
        let vm = makeSUT()
        XCTAssertFalse(vm.advanceToCompletion(), "Nothing to complete before a session starts")
        XCTAssertNil(vm.completedDuration)
    }

    func testAdvanceToCompletion_returnsFalseWhileCountingDown() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 3)

        XCTAssertFalse(vm.advanceToCompletion(), "No active duration while counting down")
        XCTAssertNil(vm.completedDuration)
    }

    // MARK: - Pause / resume / stop

    func testPause_setsPausedState_andPlaysPausedSound() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        vm.pause()

        XCTAssertEqual(vm.meditationState, .paused)
        XCTAssertTrue(sound.played.contains(.paused))
    }

    func testResume_returnsToStartedState_andPlaysResumedSound() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)
        vm.pause()

        vm.resume()

        XCTAssertEqual(vm.meditationState, .started, "Resuming must leave the paused state")
        XCTAssertTrue(sound.played.contains(.resumed))
    }

    func testPauseThenComplete_publishesSingleEvent() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)
        vm.pause()

        XCTAssertTrue(vm.advanceToCompletion())

        XCTAssertEqual(capture.completedCount, 1)
        XCTAssertEqual(vm.meditationState, .finished)
    }

    func testPause_whenIdle_isNoOp() {
        let vm = makeSUT()

        vm.pause()

        XCTAssertEqual(vm.meditationState, .notStarted)
        XCTAssertFalse(sound.played.contains(.paused))
    }

    func testResume_whenNotPaused_isNoOp() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        vm.resume()

        XCTAssertEqual(vm.meditationState, .started)
        XCTAssertFalse(sound.played.contains(.resumed))
    }

    func testStop_returnsToNotStarted() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        vm.stop()

        XCTAssertEqual(vm.meditationState, .notStarted)
        XCTAssertNil(vm.completedDuration)
        XCTAssertEqual(capture.completedCount, 0)
    }

    func testStop_duringCountdownReturnsToNotStarted() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 3)

        vm.stop()

        XCTAssertEqual(vm.meditationState, .notStarted)
        XCTAssertNil(vm.countdownRemaining)
    }

    // MARK: - Countdown

    func testStartWithCountdown_exposesRemaining_andPlaysTick() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 3)

        XCTAssertEqual(vm.countdownRemaining, 3)
        XCTAssertTrue(sound.played.contains(.countdownTick))
        XCTAssertEqual(vm.meditationState, .started)
    }

    func testStartWithoutCountdown_hasNoRemaining_andNoTick() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        XCTAssertNil(vm.countdownRemaining)
        XCTAssertFalse(sound.played.contains(.countdownTick))
    }

    // MARK: - Phase sounds & progress

    func testStartEmitsPhaseSound_forFirstPhase() {
        let vm = makeSUT()
        vm.start(with: .oneMin, countdown: 0)

        let phaseSounds = sound.played.compactMap { sound -> MeditationSound? in
            if case .phase = sound { return sound }
            return nil
        }
        XCTAssertFalse(phaseSounds.isEmpty, "Entering the session must announce the first breathing phase")
        XCTAssertEqual(vm.progress, 0, "Freshly anchored session has no elapsed time yet")
        XCTAssertEqual(vm.currentPhaseIndex, 0)
    }

    func testTitleAndPhases_areMirroredFromMeditation() {
        let vm = makeSUT()

        XCTAssertEqual(vm.meditationTitle, "Test Breath")
        XCTAssertEqual(vm.breathingPhases, makeMeditation().breathingStyle.pattern.phases)
        XCTAssertNil(vm.currentPhase, "No phase before a session starts")
    }

    func testDefaultInit_usesSharedPlayers() {
        let vm = MeditationViewModel(meditation: makeMeditation())
        XCTAssertNotNil(vm.meditation)
        XCTAssertEqual(vm.meditationState, .notStarted)
    }
}

// MARK: - Test doubles

private final class FakeSoundPlayer: SoundPlaying {
    private(set) var played: [MeditationSound] = []
    func play(_ sound: MeditationSound) {
        played.append(sound)
    }
}

private final class MeditationEventCapture {
    private(set) var events: [DomainEvent] = []

    init(bus: DomainEventBus) {
        _ = bus.subscribe { [weak self] event in
            self?.events.append(event)
        }
    }

    var completedCount: Int {
        events.filter {
            if case .meditationCompleted = $0 { return true }
            return false
        }.count
    }
}
