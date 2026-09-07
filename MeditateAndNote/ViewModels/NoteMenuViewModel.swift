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

    private var hasLoaded = false

    var error: NoteOperationError?

    let searchState: SearchState

    init(notes: any NoteProvidable & NoteManageable,
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.notes = notes
        self.eventBus = eventBus
        self.searchState = SearchState()
        subscribeToNoteEvents()
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

    // MARK: - Domain Events

    private func subscribeToNoteEvents() {
        eventBus.subscribe { [weak self] event in
            switch event {
            case .noteCreated, .noteUpdated, .noteDeleted:
                // Hop to the main actor: Observable state must be mutated on
                // the main thread. NoteManager has already recomputed
                // currentNotes before publishing, so a local reload suffices.
                Task { @MainActor [weak self] in
                    await self?.loadNotes()
                }
            case .meditationCompleted:
                break
            case .aiDraftGenerated:
                break
            }
        }
    }
}
