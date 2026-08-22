//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

//MARK: - MeditationViewModel

final class MeditationViewModel: ObservableObject {
    private enum Session {
        case idle
        case active(BreathingClock, duration: SessionDuration)
        case finished
    }

    private let meditation: Meditation
    private let eventBus: DomainEventPublisher
    @Published private var session: Session = .idle
    @Published private var remaining: TimeInterval = 0
    @Published var phaseProgress: Double = 0

    private var timer: Timer?
    private var phaseTimer: Timer?

    var meditationTitle: String {
        core.meditationTitle
    }

    var currentPhase: BreathingPhase? {
        guard case .active(let clock, _) = session else { return nil }
        return clock.currentPhase
    }

    var progress: Float {
        guard case .active(_, let duration) = session else { return 0 }
        return core.progress(totalDuration: duration, currentTime: remaining)
    }

    var meditationState: MeditationState {
        switch session {
        case .idle:
            return .notStarted
        case .finished:
            return .finished
        case .active(let clock, _):
            return clock.isPaused ? .paused : .started
        }
    }

    private var core: MeditationCore

    init(meditation: Meditation, eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.meditation = meditation
        self.eventBus = eventBus
        self.core = MeditationCore(meditation: meditation)
    }

    func start(with duration: MeditationDuration) {
        let durationValue = SessionDuration(duration)
        remaining = durationValue.seconds
        session = .active(BreathingClock(pattern: meditation.breathingStyle.pattern), duration: durationValue)
        applyClock()

        timer?.invalidate()
        phaseTimer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remaining > 0 {
                withAnimation(.linear(duration: 0.3)) {
                    self.remaining -= 1
                }
                if self.remaining <= 0 {
                    DispatchQueue.main.async {
                        self.finish()
                    }
                }
            }
        }

        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.meditationState == .started else { return }
            self.tickClock()
        }
    }

    func pause() {
        guard case .active(var clock, let duration) = session, !clock.isPaused else { return }
        clock.pause()
        session = .active(clock, duration: duration)
        applyClock()
    }

    func resume() {
        guard case .active(var clock, let duration) = session, clock.isPaused else { return }
        clock.resume()
        session = .active(clock, duration: duration)
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        session = .idle
        remaining = 0
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
        guard case .active(var clock, let duration) = session else { return }

        _ = clock.advanceIfPhaseCompleted()
        session = .active(clock, duration: duration)

        withAnimation(.linear(duration: 0.1)) {
            phaseProgress = clock.phaseProgress()
        }
    }

    func applyClock() {
        guard case .active(let clock, _) = session else {
            phaseProgress = 0
            return
        }
        phaseProgress = clock.phaseProgress()
    }

    func finish() {
       DispatchQueue.main.async {
           self.timer?.invalidate()
           self.phaseTimer?.invalidate()

           guard case .active(_, let duration) = self.session else { return }
           let completedSession = MeditationSession(
               meditationId: self.meditation.id,
               completedAt: .now,
               duration: duration
           )

           // Single write path: subscribers persist the session and update the streak
           self.eventBus.publish(MeditationCompleted(session: completedSession))

           self.session = .finished
           self.remaining = 0
           withAnimation(.easeOut(duration: 0.8)) {
               self.phaseProgress = 0
           }
       }
   }
}
