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

    static func handles(_ event: DomainEvent) -> Bool {
        switch event {
        case .noteCreated, .noteUpdated, .noteDeleted:
            return true
        case .meditationCompleted, .aiDraftGenerated, .aiDraftMetric, .noteInsightsUpdated:
            return false
        }
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