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
        case active(BreathingClock)
        case finished
    }

    private let meditation: Meditation
    private let eventBus: DomainEventPublisher
    @Published private var session: Session = .idle
    @Published private var remaining: TimeInterval = 0
    @Published var currentPhase: BreathingPhase?
    @Published var phaseProgress: Double = 0

    private var totalDuration: SessionDuration?
    private var timer: Timer?
    private var phaseTimer: Timer?

    var meditationTitle: String {
        core.meditationTitle
    }

    var progress: Float {
        core.progress(totalDuration: totalDuration?.seconds ?? 0, currentTime: remaining)
    }

    var label: String {
        core.label(for: totalDuration?.seconds ?? 0)
    }

    var meditationState: MeditationState {
        switch session {
        case .idle:
            return .notStarted
        case .finished:
            return .finished
        case .active(let clock):
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
        totalDuration = durationValue
        remaining = durationValue.seconds
        session = .active(BreathingClock(pattern: meditation.breathingStyle.pattern))
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
        guard case .active(var clock) = session, !clock.isPaused else { return }
        clock.pause()
        session = .active(clock)
        applyClock()
    }

    func resume() {
        guard case .active(var clock) = session, clock.isPaused else { return }
        clock.resume()
        session = .active(clock)
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        session = .idle
        remaining = 0
        totalDuration = nil
        currentPhase = nil
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
        guard case .active(var clock) = session else { return }

        _ = clock.advanceIfPhaseCompleted()
        session = .active(clock)

        withAnimation(.linear(duration: 0.1)) {
            phaseProgress = clock.phaseProgress()
        }
        currentPhase = clock.currentPhase
    }

    func applyClock() {
        guard case .active(let clock) = session else {
            currentPhase = nil
            phaseProgress = 0
            return
        }
        currentPhase = clock.currentPhase
        phaseProgress = clock.phaseProgress()
    }

    func finish() {
       DispatchQueue.main.async {
           self.timer?.invalidate()
           self.phaseTimer?.invalidate()

           guard let duration = self.totalDuration else { return }
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
               self.currentPhase = nil
               self.phaseProgress = 0
           }
       }
   }
}

// MARK: - MeditationState

enum MeditationState {
    case notStarted
    case started
    case paused
    case finished

    var progressText: String {
        switch self {
        case .notStarted:
            return "Start"
        case .started:
            return "Tap to Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Next"
        }
    }
}

// MARK: - MeditationDuration
public enum MeditationDuration: TimeInterval, CaseIterable, Identifiable {
    case oneMin = 60
    case threeMin = 180
    case fiveMin = 300

    public var id: TimeInterval { rawValue }

    var minutes: Int {
        Int(rawValue / 60)
    }

    var label: String {
        let measurement = Measurement(value: Double(minutes), unit: UnitDuration.minutes)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current
        return formatter.string(from: measurement)
    }
}
