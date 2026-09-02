//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

//MARK: - MeditationViewModel
@MainActor
@Observable
final class MeditationViewModel {
    
    let meditation: Meditation
    private let eventBus: DomainEventPublisher
    private let soundPlayer: SoundPlaying
    private var engine: MeditationSessionEngine
    private(set) var phaseProgress: Double = 0
    private(set) var completedDuration: MeditationDuration?
    
    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var phaseTimer: Timer?

    var meditationTitle: String {
        meditation.title.rawValue
    }
    
    var currentPhase: BreathingPhase? {
        engine.currentPhase
    }
    
    var breathingPhases: [BreathingPhase] {
        meditation.breathingStyle.pattern.phases
    }
    
    var currentPhaseIndex: Int {
        engine.currentPhaseIndex
    }
    
    var countdownRemaining: Int? {
        engine.countdownRemaining
    }
    
    var progress: Float {
        engine.progress
    }
    
    var meditationState: MeditationState {
        switch engine.state {
        case .idle:
            return .notStarted
        case .finished:
            return .finished
        case .countdown:
            return .started
        case .active(let clock, _, _, _, _):
            return clock.isPaused ? .paused : .started
        }
    }
    
    init(meditation: Meditation,
         eventBus: DomainEventPublisher = DomainEventBus.shared,
         soundPlayer: SoundPlaying = SoundPlayer.shared) {
        self.meditation = meditation
        self.eventBus = eventBus
        self.soundPlayer = soundPlayer
        self.engine = MeditationSessionEngine(pattern: meditation.breathingStyle.pattern)
    }
    
    deinit {
        timer?.invalidate()
        phaseTimer?.invalidate()
    }
}

//MARK: - Timer methods
extension MeditationViewModel {
    /// Starts a session from a preset duration (the current picker UI).
    func start(with duration: MeditationDuration, countdown: Int = 3) {
        start(with: SessionDuration(duration), countdown: countdown)
    }

    /// Starts a session from any positive duration. Wall-clock aligned, so
    /// custom durations are supported without any extra bookkeeping.
    func start(with duration: SessionDuration, countdown: Int = 3) {
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil
        phaseTimer = nil

        apply(engine.start(duration: duration, countdown: countdown))
        if engine.isCountingDown {
            timer = scheduleTimer(interval: 1.0) { [weak self] _ in
                guard let self else { return }
                self.tickCountdown()
            }
        } else {
            scheduleSessionTimers()
        }
    }
    
    func pause() {
        apply(engine.pause())
    }
    
    func resume() {
        apply(engine.resume())
    }
    
    func stop() {
        apply(engine.stop())
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil
        phaseTimer = nil
    }

    /// Test seam: drives the engine to completion deterministically without
    /// waiting on real timers.
    @discardableResult
    func advanceToCompletion() -> Bool {
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil
        phaseTimer = nil
        guard let duration = engine.activeDuration else { return false }
        apply(engine.forceComplete(duration: duration))
        return true
    }

}

//MARK: - Private methods

private extension MeditationViewModel {
    
    func tickCountdown() {
        apply(engine.tickCountdown())
        if engine.isActive {
            timer?.invalidate()
            phaseTimer?.invalidate()
            timer = nil
            phaseTimer = nil
            scheduleSessionTimers()
        }
    }
    
    func tickClock() {
        apply(engine.tickClock())
        if engine.isFinished {
            timer?.invalidate()
            phaseTimer?.invalidate()
            timer = nil
            phaseTimer = nil
        }
    }
    
    func tickSecond() {
        apply(engine.tickSecond())
        if engine.isFinished {
            timer?.invalidate()
            phaseTimer?.invalidate()
            timer = nil
            phaseTimer = nil
        }
    }
    
    func scheduleSessionTimers() {
        guard engine.isActive else { return }
        timer = scheduleTimer(interval: 1.0) { [weak self] _ in
            guard let self else { return }
            self.tickSecond()
        }
        phaseTimer = scheduleTimer(interval: 0.1) { [weak self] _ in
            guard let self else { return }
            guard case .active(let clock, _, _, _, _) = self.engine.state, !clock.isPaused else { return }
            self.tickClock()
        }
    }
    
    func scheduleTimer(interval: TimeInterval, block: @escaping @MainActor @Sendable (Timer) -> Void) -> Timer? {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            // Timer.scheduledTimer fires on the run loop it was created on,
            // which is the main run loop here (this VM is MainActor-isolated).
            MainActor.assumeIsolated {
                block(timer)
            }
        }
    }
    
    func apply(_ events: [MeditationSessionEngine.Event]) {
        for event in events {
            switch event {
            case .countdownTick:
                soundPlayer.play(.countdownTick)
            case .sessionStarted:
                break
            case .phaseChanged(let phase):
                soundPlayer.play(.phase(phase.type))
            case .sessionPaused:
                soundPlayer.play(.paused)
            case .sessionResumed:
                soundPlayer.play(.resumed)
            case .completed(let duration):
                let completedSession = MeditationSession(
                    meditationId: self.meditation.id,
                    completedAt: .now,
                    duration: duration
                )
                self.completedDuration = MeditationDuration(rawValue: duration.seconds) ?? .fiveMin
                self.eventBus.publish(.meditationCompleted(completedSession))
                self.soundPlayer.play(.finished)
            }
        }
        phaseProgress = engine.phaseProgress()
    }
}
