//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation
import Observation

//MARK: - NoteCore (pure domain logic)

struct NoteCore {
    func makeNote(id: NoteID, title: String, body: String, date: Date) -> Note {
        Note(id: id, title: MeditationTitle(title), content: body, date: date)
    }
    
    func isValid(_ note: Note) -> Bool {
        !note.title.rawValue.isEmpty(trim: true) && !note.content.isEmpty
    }
    
    mutating func normalizeTitle(_ title: inout String) {
        if title.isEmpty(trim: true) { title = "Untitled" }
    }
}

// Helper extension for string trimming check
private extension String {
    func isEmpty(trim: Bool = false) -> Bool {
        trim ? self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : self.isEmpty
    }
}

//MARK: - NoteEditorViewModel

@Observable
final class NoteEditorViewModel {
    var title: String = ""
    var body: String = ""
    var isDirty: Bool = false

    private let noteRepository: NoteRepository
    private let syncCoordinator: NoteSyncCoordinator
    private let eventBus: DomainEventPublisher
    private var noteId: NoteID?
    private var noteDate: Date?
    private var saveTask: Task<Void, Never>?
    private var autosaveWorkItem: DispatchWorkItem?

    var isNewNote: Bool { noteId == nil }

    private var noteCore = NoteCore()

    init(noteId: NoteID? = nil,
         noteRepository: NoteRepository,
         syncCoordinator: NoteSyncCoordinator,
         eventBus: DomainEventPublisher = DomainEventBus.shared) {
        self.noteId = noteId
        self.noteRepository = noteRepository
        self.syncCoordinator = syncCoordinator
        self.eventBus = eventBus

        if let noteId {
            Task { await loadNote(noteId) }
        }
    }

    deinit {
        saveTask?.cancel()
        autosaveWorkItem?.cancel()
    }

    // MARK: - Load

    private func loadNote(_ id: NoteID) async {
        do {
            let note = try await noteRepository.find(id)
            if let note = note {
                title = note.title.rawValue
                body = note.content
                noteDate = note.date
            }
            isDirty = false
        } catch {
            print("NoteEditorViewModel: failed to load note — \(error)")
        }
    }
    
    // MARK: - Autosave (debounced)
    
    func onTextChanged() {
        isDirty = true
        autosaveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isDirty else { return }
            Task { await self.save() }
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
    
    // MARK: - Save
    
    func save() async {
        let isNew = noteId == nil
        let id = noteId ?? NoteID()
        noteCore.normalizeTitle(&title)
        let date = noteDate ?? Date()
        let note = noteCore.makeNote(id: id, title: title, body: body, date: date)

        do {
            try await syncCoordinator.save(note, strategy: .hybrid)
            noteId = id
            noteDate = date
            isDirty = false
            eventBus.publish(isNew ? NoteCreated(note: note) : NoteUpdated(note: note))
        } catch {
            print("NoteEditorViewModel: save failed — \(error)")
        }
    }

    // MARK: - Delete

    func delete() async {
        guard let id = noteId else { return }
        do {
            try await syncCoordinator.delete(id, strategy: .hybrid)
        } catch {
            print("NoteEditorViewModel: delete failed — \(error)")
        }
    }
}

