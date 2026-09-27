//
//  MeditationScope.swift
//  MeditateAndNote
//

import Foundation

struct MeditationScope: DomainEventRouting {
    let service: MeditationService
    let store: CoreDataSessionStore
    let selectionStore: MeditationSelectionStore

    init() {
        service = SampleMeditationService()
        store = CoreDataSessionStore()
        selectionStore = MeditationSelectionStore()
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
