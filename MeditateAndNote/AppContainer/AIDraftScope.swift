//
//  AIDraftScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

struct AIDraftScope: DomainEventRouting {
    let service: any AIDraftService
    let sessionStore: any AIDraftSessionStore
    let metricStore: any AIDraftMetricStore
    let manager: AIDraftManager

    init(eventBus: DomainEventPublisher = DomainEventBus.shared) {
        service = AIDraftServiceFactory.make()
        sessionStore = CoreDataAIDraftSessionStore()
        metricStore = CoreDataAIDraftMetricStore()
        manager = AIDraftManager(service: service, store: sessionStore, eventBus: eventBus)
    }

    static func handles(_ event: DomainEvent) -> Bool {
        switch event {
        case .noteDeleted, .aiDraftMetric:
            return true
        case .noteCreated, .noteUpdated, .meditationCompleted, .aiDraftGenerated, .noteInsightsUpdated:
            return false
        }
    }

    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteDeleted(let noteID):
            try? await manager.discardSessions(for: noteID)
        case .aiDraftMetric:
            await metricStore.handle(event)
        default:
            break
        }
    }
}
