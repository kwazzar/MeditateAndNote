//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//

import Foundation
import Observation

@Observable
final class NoteEditorViewModel {
    var title: String = ""
    var body: String = ""
    var isDirty: Bool = false

    private let repository: NotesRepository
    private let streakTracker: StreakTracker?
    private var noteId: UUID?
    private var saveTask: Task<Void, Never>?
    private var autosaveWorkItem: DispatchWorkItem?

    var isNewNote: Bool { noteId == nil }

    init(noteId: UUID? = nil, repository: NotesRepository, streakTracker: StreakTracker? = nil) {
        self.noteId = noteId
        self.repository = repository
        self.streakTracker = streakTracker

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
            let note = try await repository.getItem(id: id.uuidString, strategy: .remoteFirst)
            title = note.title
            body = note.content
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
        let note = Note(id: id, title: title, content: body, date: Date())

        do {
            try await repository.saveItem(note, strategy: .localOnly)
            noteId = id
            isDirty = false
            streakTracker?.markNoteCreated(date: note.date)
        } catch {
            print("NoteEditorViewModel: save failed — \(error)")
        }
    }

    // MARK: - Delete

    func delete() async {
        guard let id = noteId else { return }
        do {
            try await repository.deleteItem(id: id.uuidString, strategy: .localOnly)
        } catch {
            print("NoteEditorViewModel: delete failed — \(error)")
        }
    }
}
