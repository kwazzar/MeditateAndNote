//
//  NoteMenuViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import Foundation
import OSLog

@MainActor
@Observable
final class NoteMenuViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteMenuViewModel")
    private let notes: any NoteProvidable & NoteManageable
    private let eventBus: DomainEventPublisher
    private let semanticSearch: (any SemanticSearchProvidable)?

    private var hasLoaded = false
    private var eventsTask: Task<Void, Never>?
    private var semanticTask: Task<Void, Never>?

    var error: NoteOperationError?

    let searchState: SearchState

    init(notes: any NoteProvidable & NoteManageable,
         eventBus: DomainEventPublisher = DomainEventBus.shared,
         semanticSearch: (any SemanticSearchProvidable)? = nil) {
        self.notes = notes
        self.eventBus = eventBus
        self.semanticSearch = semanticSearch
        self.searchState = SearchState()
        startEventListening()
    }

    /// Loads data exactly once. Subsequent tab appearances do not re-fetch:
    /// updates arrive through domain events instead.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await notes.refresh()
        await loadNotes()
    }

    private func loadNotes() async {
        let allNotes = await notes.currentNotes
        searchState.setAvailableItems(allNotes)
    }

    func refreshNotes() async {
        await loadNotes()
    }

    func deleteNote(_ note: Note) async {
        do {
            try await notes.delete(with: note.id)
            await refreshNotes()
        } catch {
            self.error = .deleteFailed(note.id)
            logger.error("Error deleting note — \(error.localizedDescription)")
        }
    }

    /// Updates the query and, when keyword matching finds nothing, falls back
    /// to semantic ranking over the full collection (auto mode).
    func updateSearch(_ text: String) {
        let query = SearchQuery(text: text)
        searchState.setSearchText(query)

        semanticTask?.cancel()
        searchState.setSemanticSearching(false)
        searchState.setSemanticMatches([])

        guard query != .all, searchState.keywordHits.isEmpty,
              let semanticSearch else { return }

        searchState.setSemanticSearching(true)
        let semanticQuery = SemanticQuery(text: query.text)
        semanticTask = Task { [weak self] in
            guard let self else { return }
            let matches = await semanticSearch.search(
                matching: semanticQuery,
                in: searchState.availableItems
            )
            guard !Task.isCancelled else { return }
            searchState.setSemanticMatches(matches)
            searchState.setSemanticSearching(false)
        }
    }

    var isUsingSemanticResults: Bool {
        searchState.searchText != .all
            && searchState.keywordHits.isEmpty
            && (searchState.hasSemanticResults || searchState.isSemanticSearching)
    }
}

// MARK: - Domain Events

@MainActor
private extension NoteMenuViewModel {
    /// The single consumer of note events. Chain:
    ///
    ///     eventBus.publish(event)            // emitter's thread (e.g. NoteManager actor)
    ///     └─ AsyncStream<DomainEvent>.events // bus fans the event out to each consumer
    ///        └─ this Task (for await)        // stored in `eventsTask`, cancellable
    ///           └─ switch, on @MainActor     // Observable state is mutated on main
    ///
    /// Runs sequentially in publish order. NoteManager has already recomputed
    /// currentNotes before publishing, so a local reload suffices.
    func startEventListening() {
        eventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.eventBus.events {
                switch event {
                case .noteCreated, .noteUpdated, .noteDeleted:
                    await self.loadNotes()
                case .meditationCompleted, .aiDraftGenerated, .aiDraftMetric, .noteInsightsUpdated:
                    break
                }
            }
        }
    }
}
