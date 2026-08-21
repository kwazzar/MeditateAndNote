//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

//MARK: - MeditationCore (pure domain logic)

struct MeditationCore {
    let meditation: Meditation
    
    var meditationTitle: String {
        meditation.title.rawValue
    }
    
    func progress(totalDuration: TimeInterval, currentTime: TimeInterval) -> Float {
        guard totalDuration > 0 else { return 0 }
        return Float((totalDuration - currentTime) / totalDuration)
    }
    
    func minutes(from duration: TimeInterval) -> Int {
        Int(duration / 60)
    }
    
    func label(for duration: TimeInterval) -> String {
        let measurement = Measurement(value: Double(minutes(from: duration)), unit: UnitDuration.minutes)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.locale = Locale.current
        return formatter.string(from: measurement)
    }
    
    mutating func advancePhase(currentPhaseIndex: Int, pattern: BreathingPattern) -> (newIndex: Int, newPhase: BreathingPhase, cycleCountIncreased: Bool) {
        let phases = pattern.phases
        guard !phases.isEmpty else { return (currentPhaseIndex, phases.first ?? BreathingPhase(type: .inhale, duration: 0), false) }
        
        let newIndex = (currentPhaseIndex + 1) % phases.count
        let cycleIncreased = newIndex == 0
        let newPhase = phases[newIndex]
        
        return (newIndex, newPhase, cycleIncreased)
    }
}

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
    @Published var showTimeMeditation: Bool = true
    
    private var totalDuration: TimeInterval = 0
    private var timer: Timer?
    private var phaseTimer: Timer?
    private var currentPhaseIndex: Int = 0
    private var phaseStartTime: Date = Date()
    private var pausedPhaseElapsed: TimeInterval = 0
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
        currentPhaseIndex = 0
        cycleCount = 0
        meditationState = .started
        pausedPhaseElapsed = 0
        
        timer?.invalidate()
        phaseTimer?.invalidate()
        
        startBreathingCycle()
        
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
    }
    
    func pause() {
        guard meditationState == .started else { return }
        
        meditationState = .paused
        
        if currentPhase != nil {
            let elapsed = Date().timeIntervalSince(phaseStartTime)
            pausedPhaseElapsed = elapsed
        }
        
        phaseTimer?.invalidate()
    }
    
    func resume() {
        guard meditationState == .paused else { return }
        
        meditationState = .started
        
        phaseStartTime = Date().addingTimeInterval(-pausedPhaseElapsed)
        startPhaseTimer()
    }
    
    func stop() {
        timer?.invalidate()
        phaseTimer?.invalidate()
        meditationState = .notStarted
        meditationTime = 0
        phaseProgress = 0
        cycleCount = 0
        currentPhase = nil
        pausedPhaseElapsed = 0
    }
    
    deinit {
        timer?.invalidate()
        phaseTimer?.invalidate()
    }
}

//MARK: - Private methods

private extension MeditationViewModel {
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
           
           withAnimation(.easeOut(duration: 0.8)) {
               self.currentPhase = nil
               self.phaseProgress = 0
           }
           
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
               self.meditationState = .finished
           }
       }
   }
   
    func startBreathingCycle() {
        let pattern = meditation.breathingStyle.pattern
        guard !pattern.phases.isEmpty else { return }
        
        let result = core.advancePhase(currentPhaseIndex: currentPhaseIndex, pattern: pattern)
        currentPhaseIndex = result.newIndex
        currentPhase = result.newPhase
        phaseProgress = 0
        pausedPhaseElapsed = 0
        
        startPhaseTimer()
    }
    
    func startPhaseTimer() {
        guard let phase = currentPhase else { return }
        
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            guard self.meditationState == .started else { return }
            
            let elapsed = Date().timeIntervalSince(self.phaseStartTime)
            let progress = min(elapsed / phase.duration, 1.0)
            
            withAnimation(.linear(duration: 0.1)) {
                self.phaseProgress = progress
            }
            
            if progress >= 1.0 {
                self.moveToNextPhase()
            }
        }
    }
    
    func moveToNextPhase() {
        phaseTimer?.invalidate()
        
        let pattern = meditation.breathingStyle.pattern
        let result = core.advancePhase(currentPhaseIndex: currentPhaseIndex, pattern: pattern)
        currentPhaseIndex = result.newIndex
        currentPhase = result.newPhase
        
        if result.cycleCountIncreased {
            cycleCount += 1
        }
        
        phaseStartTime = Date()
        phaseProgress = 0
        pausedPhaseElapsed = 0
        
        startPhaseTimer()
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