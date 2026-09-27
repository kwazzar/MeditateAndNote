//
//  AIDraftScope.swift
//  MeditateAndNote
//

import Foundation

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