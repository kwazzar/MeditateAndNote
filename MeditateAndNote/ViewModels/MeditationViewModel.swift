//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

enum BreathingAnimationStyle: String, CaseIterable {
    case rings = "Rings"
    case path = "Path"
}

//MARK: - MeditationViewModel
@Observable
final class MeditationViewModel {
    
    private let meditation: Meditation
    private let eventBus: DomainEventPublisher
    private let soundPlayer: SoundPlaying
    private var engine: MeditationSessionEngine
    private(set) var phaseProgress: Double = 0
    
    private var timer: Timer?
    private var phaseTimer: Timer?
    
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
        case .active(let clock, _, _):
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
    func start(with duration: MeditationDuration, countdown: Int = 3) {
        let durationValue = SessionDuration(duration)
        timer?.invalidate()
        phaseTimer?.invalidate()
        timer = nil
        phaseTimer = nil
        
        apply(engine.start(duration: durationValue, countdown: countdown))
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
            guard case .active(let clock, _, _) = self.engine.state, !clock.isPaused else { return }
            self.tickClock()
        }
    }
    
    func scheduleTimer(interval: TimeInterval, block: @escaping (Timer) -> Void) -> Timer? {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: block)
    }
    
    func apply(_ events: [MeditationSessionEngine.Event]) {
        for event in events {
            switch event {
            case .countdownTick:
                soundPlayer.play(.countdownTick)
            case .sessionStarted:
                soundPlayer.play(.started)
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
                self.eventBus.publish(.meditationCompleted(completedSession))
                self.soundPlayer.play(.finished)
            }
        }
        phaseProgress = engine.phaseProgress()
    }
}
