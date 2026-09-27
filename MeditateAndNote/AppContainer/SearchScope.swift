//
//  SearchScope.swift
//  MeditateAndNote
//

import Foundation

struct SearchScope: DomainEventRouting {
    let embeddingService: any EmbeddingService
    let noteEmbeddingStore: any NoteEmbeddingStore
    let manager: SemanticSearchManager

    init() {
        embeddingService = NLEmbeddingService()
        noteEmbeddingStore = CoreDataNoteEmbeddingStore()
        manager = SemanticSearchManager(service: embeddingService, store: noteEmbeddingStore)
    }

    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteDeleted(let noteID):
            await manager.deleteEmbedding(for: noteID)
        default:
            break
        }
    }
}
