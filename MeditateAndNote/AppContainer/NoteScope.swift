//
//  NoteScope.swift
//  MeditateAndNote
//

import Foundation

struct NoteScope: DomainEventRouting {
    let manager: NoteManager
    let insightManager: NoteInsightManager

    init(localDataSource: any NoteDataSource, eventBus: DomainEventPublisher = DomainEventBus.shared) {
        manager = NoteManager(local: localDataSource, eventBus: eventBus)
        insightManager = NoteInsightManager(
            analyzer: FoundationModelsNoteAnalyzer(),
            store: CoreDataNoteInsightStore(),
            notesProvider: { [manager] in await manager.currentNotes },
            eventBus: eventBus
        )
    }

    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteCreated, .noteUpdated:
            await insightManager.handle(event)
        case .noteDeleted:
            await insightManager.handle(event)
        default:
            break
        }
    }
}