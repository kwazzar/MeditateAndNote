//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation
import Observation
import OSLog

//MARK: - EditTarget (draft state machine)

enum EditTarget {
    case new
    case loading(id: NoteID)
    case loaded(id: NoteID, persisted: Note)
    case notFound(id: NoteID)
}

//MARK: - NoteEditorViewModel

@Observable
final class NoteEditorViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteEditorViewModel")

    var title: String = ""
    var body: String = ""

    private let notes: any NoteProvidable & NoteManagable
    private var target: EditTarget
    private var saveTask: Task<Void, Never>?
    private var autosaveWorkItem: DispatchWorkItem?

    var isNewNote: Bool {
        if case .new = target { return true }
        return false
    }

    var isDirty: Bool {
        switch target {
        case .loading:
            return false
        case .new, .notFound:
            return !(title.isEmpty && body.isEmpty)
        case let .loaded(_, persisted):
            return persisted.title.rawValue != title || persisted.content != body
        }
    }

    init(noteId: NoteID? = nil,
         notes: any NoteProvidable & NoteManagable) {
        self.target = noteId.map(EditTarget.loading) ?? .new
        self.notes = notes

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
            if let note = try await notes.note(with: id) {
                title = note.title.rawValue
                body = note.content
                target = .loaded(id: id, persisted: note)
            } else {
                target = .notFound(id: id)
            }
        } catch {
            logger.error("Failed to load note — \(error.localizedDescription)")
            target = .notFound(id: id)
        }
    }

    // MARK: - Autosave (debounced)

    func onTextChanged() {
        autosaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isDirty else { return }
            saveTask?.cancel()
            saveTask = Task { await self.save() }
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    // MARK: - Save

    func save() async {
        switch target {
        case .loading:
            return

        case .new:
            await saveNewNote()

        case let .loaded(id, persisted):
            await saveExisting(id: id, persisted: persisted)

        case let .notFound(id):
            await saveExisting(id: id, persisted: nil)
        }
    }

    private func saveNewNote() async {
        let id = NoteID()
        let note = Note(id: id, title: NoteTitle(title), content: body, date: Date())
        title = note.title.rawValue

        do {
            try await notes.add(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            logger.error("Save failed — \(error.localizedDescription)")
        }
    }

    private func saveExisting(id: NoteID, persisted: Note?) async {
        let date = persisted?.date ?? Date()
        let note = Note(id: id, title: NoteTitle(title), content: body, date: date)
        title = note.title.rawValue

        do {
            if let persisted, persisted == note {
                return
            }
            try await notes.update(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            logger.error("Save failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func delete() async {
        switch target {
        case .new:
            return
        case .loading:
            return
        case let .loaded(id, _):
            await performDelete(id)
        case let .notFound(id):
            await performDelete(id)
        }
    }

    private func performDelete(_ id: NoteID) async {
        do {
            try await notes.delete(with: id)
        } catch {
            logger.error("Delete failed — \(error.localizedDescription)")
        }
    }
}
