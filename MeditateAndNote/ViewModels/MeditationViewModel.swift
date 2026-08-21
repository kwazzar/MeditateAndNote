//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

//MARK: - MeditationViewModel

final class MeditationViewModel: ObservableObject {
    private let meditation: Meditation
    private let sessionStore: MeditationSessionStore?
    private let eventBus: DomainEventPublisher
    @Published private var meditationTime: TimeInterval = 0
    @Published var currentPhase: BreathingPhase?
    @Published var phaseProgress: Double = 0
    @Published var cycleCount: Int = 0
    @Published var meditationState: MeditationState = .notStarted

    private var totalDuration: TimeInterval = 0
    private var timer: Timer?
    private var phaseTimer: Timer?
    private var clock: BreathingClock?
    private var core: MeditationCore

    var meditationTitle: String {
        core.meditationTitle
    }

    var progress: Float {
        core.progress(totalDuration: totalDuration, currentTime: meditationTime)
    }

    var minutes: Int {
        core.minutes(from: totalDuration)
    }

    var label: String {
        core.label(for: totalDuration)
    }

    init(meditation: Meditation, sessionStore: MeditationSessionStore? = nil, eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.meditation = meditation
        self.sessionStore = sessionStore
        self.eventBus = eventBus
        self.core = MeditationCore(meditation: meditation)
    }

    func start(with duration: MeditationDuration) {
        totalDuration = duration.rawValue
        meditationTime = duration.rawValue
        cycleCount = 0
        meditationState = .started

        clock = BreathingClock(pattern: meditation.breathingStyle.pattern)
        applyClock()

        timer?.invalidate()
        phaseTimer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.meditationState == .started && self.meditationTime > 0 {
                withAnimation(.linear(duration: 0.3)) {
                    self.meditationTime -= 1
                }
            } else if self.meditationTime <= 0 {
                DispatchQueue.main.async {
                    self.finish()
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
        guard meditationState == .started else { return }

        meditationState = .paused
        clock?.pause()
        applyClock()
    }

    func resume() {
        guard meditationState == .paused else { return }

        meditationState = .started
        clock?.resume()
    }

    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        meditationState = .notStarted
        meditationTime = 0
        cycleCount = 0
        clock = nil
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
        guard var updated = clock else { return }

        if updated.advanceIfPhaseCompleted() {
            cycleCount += 1
        }
        clock = updated

        withAnimation(.linear(duration: 0.1)) {
            phaseProgress = updated.phaseProgress()
        }
        currentPhase = updated.currentPhase
    }

    func applyClock() {
        guard let updated = clock else {
            currentPhase = nil
            phaseProgress = 0
            return
        }
        currentPhase = updated.currentPhase
        phaseProgress = updated.phaseProgress()
    }

    func finish() {
       DispatchQueue.main.async {
           self.timer?.invalidate()
           self.phaseTimer?.invalidate()

           let session = MeditationSession(
               meditationId: self.meditation.id,
               completedAt: .now,
               duration: self.totalDuration
           )
           self.sessionStore?.save(session)

           // Publish domain event instead of direct call
           self.eventBus.publish(MeditationCompleted(session: session))

           self.clock = nil
           withAnimation(.easeOut(duration: 0.8)) {
               self.currentPhase = nil
               self.phaseProgress = 0
           }

           DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
               self.meditationState = .finished
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
