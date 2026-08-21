//
//  NoteEditorViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation
import Observation

//MARK: - EditTarget (draft state machine)

enum EditTarget {
    case new
    case loading(id: NoteID)
    case loaded(id: NoteID, persisted: Note?)
}

//MARK: - NoteEditorViewModel

@Observable
final class NoteEditorViewModel {
    var title: String = ""
    var body: String = ""

    private let notes: any NoteProvidable & NoteManagable
    private var target: EditTarget
    private var saveTask: Task<Void, Never>?
    private var autosaveWorkItem: DispatchWorkItem?

    private var noteCore = NoteCore()

    var isNewNote: Bool {
        if case .new = target { return true }
        return false
    }

    var isDirty: Bool {
        switch target {
        case .loading:
            return false
        case .new:
            return !(title.isEmpty && body.isEmpty)
        case let .loaded(_, persisted):
            guard let persisted else { return !(title.isEmpty && body.isEmpty) }
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
            let note = try await notes.item(with: id)
            title = note?.title.rawValue ?? ""
            body = note?.content ?? ""
            target = .loaded(id: id, persisted: note)
        } catch {
            print("NoteEditorViewModel: failed to load note — \(error)")
            target = .loaded(id: id, persisted: nil)
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
        }
    }

    private func saveNewNote() async {
        noteCore.normalizeTitle(&title)
        let date = Date()
        let id = NoteID()
        let note = noteCore.makeNote(id: id, title: title, body: body, date: date)

        do {
            try await notes.addItem(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            print("NoteEditorViewModel: save failed — \(error)")
        }
    }

    private func saveExisting(id: NoteID, persisted: Note?) async {
        noteCore.normalizeTitle(&title)
        let date = persisted?.date ?? Date()
        let note = noteCore.makeNote(id: id, title: title, body: body, date: date)

        do {
            if let persisted, persisted == note {
                return
            }
            try await notes.updateItem(note)
            target = .loaded(id: id, persisted: note)
        } catch {
            print("NoteEditorViewModel: save failed — \(error)")
        }
    }

    // MARK: - Delete

    func delete() async {
        switch target {
        case .new:
            return
        case let .loading(id):
            await performDelete(id)
        case let .loaded(id, _):
            await performDelete(id)
        }
    }

    private func performDelete(_ id: NoteID) async {
        do {
            try await notes.deleteItem(with: id)
        } catch {
            print("NoteEditorViewModel: delete failed — \(error)")
        }
    }
}
