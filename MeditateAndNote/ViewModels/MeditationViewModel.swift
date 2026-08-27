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
    
    // Session state machine: remaining time exists only while active,
    // so idle/finished states cannot carry stale progress values.
    private enum Session {
        case idle
        case countdown(remaining: Int, duration: SessionDuration)
        case active(BreathingClock, duration: SessionDuration, remaining: TimeInterval)
        case finished
    }
    
    private let meditation: Meditation
    private let eventBus: DomainEventPublisher
    private let soundPlayer: SoundPlaying
    private var session: Session = .idle
    private(set) var phaseProgress: Double = 0
    
    private var timer: Timer?
    private var phaseTimer: Timer?
    
    var meditationTitle: String {
        meditation.title.rawValue
    }
    
    var currentPhase: BreathingPhase? {
        guard case .active(let clock, _, _) = session else { return nil }
        return clock.currentPhase
    }
    
    var breathingPhases: [BreathingPhase] {
        meditation.breathingStyle.pattern.phases
    }
    
    var currentPhaseIndex: Int {
        guard case .active(let clock, _, _) = session else { return 0 }
        return clock.phaseIndex
    }
    
    var countdownRemaining: Int? {
        guard case .countdown(let remaining, _) = session else { return nil }
        return remaining
    }
    
    var progress: Float {
        guard case .active(_, let duration, let remaining) = session else { return 0 }
        guard duration.seconds > 0 else { return 0 }
        return Float((duration.seconds - remaining) / duration.seconds)
    }
    
    var meditationState: MeditationState {
        switch session {
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
        
        if countdown > 0 {
            session = .countdown(remaining: countdown, duration: durationValue)
            soundPlayer.play(.countdownTick)
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.tickCountdown()
            }
        } else {
            beginSession(durationValue)
        }
    }
    
    func pause() {
        guard case .active(var clock, let duration, let remaining) = session, !clock.isPaused else { return }
        clock.pause()
        session = .active(clock, duration: duration, remaining: remaining)
        applyClock()
        soundPlayer.play(.paused)
    }
    
    func resume() {
        guard case .active(var clock, let duration, let remaining) = session, clock.isPaused else { return }
        clock.resume()
        session = .active(clock, duration: duration, remaining: remaining)
        soundPlayer.play(.resumed)
    }
    
    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        session = .idle
        phaseProgress = 0
    }
    
}

//MARK: - Private methods

private extension MeditationViewModel {
    
    func tickCountdown() {
        guard case .countdown(let remaining, let duration) = session else { return }
        if remaining > 1 {
            session = .countdown(remaining: remaining - 1, duration: duration)
            soundPlayer.play(.countdownTick)
        } else {
            beginSession(duration)
        }
    }
    
    func beginSession(_ duration: SessionDuration) {
        session = .active(
            BreathingClock(pattern: meditation.breathingStyle.pattern),
            duration: duration,
            remaining: duration.seconds
        )
        applyClock()
        soundPlayer.play(.started)
        if let phase = currentPhase {
            soundPlayer.play(.phase(phase.type))
        }
        
        timer?.invalidate()
        phaseTimer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tickSecond()
        }
        
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard case .active(let clock, _, _) = self.session, !clock.isPaused else { return }
            self.tickClock()
        }
    }
    
    func tickClock() {
        guard case .active(var clock, let duration, let remaining) = session, !clock.isPaused else { return }
        let previousPhaseIndex = clock.phaseIndex
        _ = clock.advanceIfPhaseCompleted()
        if clock.phaseIndex != previousPhaseIndex, let phase = clock.currentPhase {
            soundPlayer.play(.phase(phase.type))
        }
        session = .active(clock, duration: duration, remaining: remaining)
        phaseProgress = clock.phaseProgress()
    }
    
    func tickSecond() {
        guard case .active(let clock, let duration, let remaining) = session, !clock.isPaused else { return }
        let nextRemaining = remaining - 1
        if nextRemaining > 0 {
            session = .active(clock, duration: duration, remaining: nextRemaining)
        } else {
            finish(duration: duration)
        }
    }
    
    func applyClock() {
        guard case .active(let clock, _, _) = session else {
            phaseProgress = 0
            return
        }
        phaseProgress = clock.phaseProgress()
    }
    
    func finish(duration: SessionDuration) {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.phaseTimer?.invalidate()
            let completedSession = MeditationSession(
                meditationId: self.meditation.id,
                completedAt: .now,
                duration: duration
            )
            self.eventBus.publish(.meditationCompleted(completedSession))
            self.soundPlayer.play(.finished)
            self.session = .finished
            self.phaseProgress = 0
        }
    }
}
