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
    func makeNote(id: UUID, title: String, body: String, date: Date) -> Note {
        Note(id: NoteID(rawValue: id), title: MeditationTitle(title), content: body, date: date)
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
    private var noteId: UUID?
    private var saveTask: Task<Void, Never>?
    private var autosaveWorkItem: DispatchWorkItem?
    
    var isNewNote: Bool { noteId == nil }
    
    private var noteCore = NoteCore()
    
    init(noteId: UUID? = nil, noteRepository: NoteRepository, syncCoordinator: NoteSyncCoordinator) {
        self.noteId = noteId
        self.noteRepository = noteRepository
        self.syncCoordinator = syncCoordinator
        
        if let noteId {
            Task { await loadNote(noteId) }
        }
    }
    
    deinit {
        saveTask?.cancel()
        autosaveWorkItem?.cancel()
    }
    
    // MARK: - Load
    
    private func loadNote(_ id: UUID) async {
        do {
            let note = try await noteRepository.find(NoteID(rawValue: id))
            if let note = note {
                title = note.title.rawValue
                body = note.content
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
        let id = noteId ?? UUID()
        noteCore.normalizeTitle(&title)
        let note = noteCore.makeNote(id: id, title: title, body: body, date: Date())
        
        do {
            try await syncCoordinator.save(note, strategy: .hybrid)
            noteId = id
            isDirty = false
            // Streak update now happens via Domain Event → StreakTracker subscriber
        } catch {
            print("NoteEditorViewModel: save failed — \(error)")
        }
    }
    
    // MARK: - Delete
    
    func delete() async {
        guard let id = noteId else { return }
        do {
            try await syncCoordinator.delete(NoteID(rawValue: id), strategy: .hybrid)
        } catch {
            print("NoteEditorViewModel: delete failed — \(error)")
        }
    }
}

