//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

//MARK: - MeditationViewModel
@Observable
final class MeditationViewModel {

    // Session state machine: remaining time exists only while active,
    // so idle/finished states cannot carry stale progress values.
    private enum Session {
        case idle
        case active(BreathingClock, duration: SessionDuration, remaining: TimeInterval)
        case finished
    }

    private let meditation: Meditation
    private let eventBus: DomainEventPublisher
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
        case .active(let clock, _, _):
            return clock.isPaused ? .paused : .started
        }
    }

    init(meditation: Meditation, eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.meditation = meditation
        self.eventBus = eventBus
    }

    func start(with duration: MeditationDuration) {
        let durationValue = SessionDuration(duration)
        session = .active(
            BreathingClock(pattern: meditation.breathingStyle.pattern),
            duration: durationValue,
            remaining: durationValue.seconds
        )
        applyClock()

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

    func pause() {
        guard case .active(var clock, let duration, let remaining) = session, !clock.isPaused else { return }
        clock.pause()
        session = .active(clock, duration: duration, remaining: remaining)
        applyClock()
    }

    func resume() {
        guard case .active(var clock, let duration, let remaining) = session, clock.isPaused else { return }
        clock.resume()
        session = .active(clock, duration: duration, remaining: remaining)
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        session = .idle
        phaseProgress = 0
    }

    deinit {
        timer?.invalidate()
        phaseTimer?.invalidate()
    }
}

//MARK: - Private methods

private extension MeditationViewModel {

    func tickClock() {
        guard case .active(var clock, let duration, let remaining) = session else { return }
        _ = clock.advanceIfPhaseCompleted()
        session = .active(clock, duration: duration, remaining: remaining)
        phaseProgress = clock.phaseProgress() // без withAnimation
    }

    func tickSecond() {
        guard case .active(let clock, let duration, let remaining) = session, !clock.isPaused else { return }
        let nextRemaining = remaining - 1
        if nextRemaining > 0 {
            session = .active(clock, duration: duration, remaining: nextRemaining) // без withAnimation
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
            self.session = .finished
            self.phaseProgress = 0 // без withAnimation
        }
    }
}
