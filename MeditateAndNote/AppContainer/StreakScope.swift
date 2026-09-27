//
//  StreakScope.swift
//  MeditateAndNote
//

import Foundation

struct StreakScope: DomainEventRouting {
    let streakTracker: StreakTracker
    let insightManager: StreakInsightManager

    init() {
        streakTracker = StreakTracker(calendar: .current, store: CoreDataStreakStore())
        insightManager = StreakInsightManager(snapshotProvider: streakTracker)
    }

    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteCreated, .noteUpdated, .noteDeleted, .meditationCompleted:
            await streakTracker.handle(event)
            insightManager.handle(event)
        default:
            break
        }
    }
}