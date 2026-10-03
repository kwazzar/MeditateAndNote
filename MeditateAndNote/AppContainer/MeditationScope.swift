//
//  MeditationScope.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

struct MeditationScope: DomainEventRouting {
    let service: MeditationService
    let store: CoreDataSessionStore
    let selectionStore: MeditationSelectionStore

    init() {
        service = SampleMeditationService()
        store = CoreDataSessionStore()
        selectionStore = MeditationSelectionStore()
    }

    static func handles(_ event: DomainEvent) -> Bool {
        switch event {
        case .meditationCompleted:
            return true
        case .noteCreated, .noteUpdated, .noteDeleted, .aiDraftGenerated, .aiDraftMetric, .noteInsightsUpdated:
            return false
        }
    }

    func handle(_ event: DomainEvent) async {
        switch event {
        case .meditationCompleted:
            await store.handle(event)
        default:
            break
        }
    }
}
