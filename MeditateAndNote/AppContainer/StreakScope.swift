//
//  StreakScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

struct StreakScope: DomainEventRouting {
    let streakTracker: StreakTracker
    let insightManager: StreakInsightManager

    init() {
        streakTracker = StreakTracker(calendar: .current, store: CoreDataStreakStore())
        insightManager = StreakInsightManager(snapshotProvider: streakTracker)
    }

    static func handles(_ event: DomainEvent) -> Bool {
        switch event {
        case .noteCreated, .noteUpdated, .noteDeleted, .meditationCompleted:
            return true
        case .aiDraftGenerated, .aiDraftMetric, .noteInsightsUpdated:
            return false
        }
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
