//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

// Home tab: resolves the last selected meditation and streak display.
// Note-list responsibilities live in NoteMenuViewModel (Notes tab).
@Observable
final class MainViewModel {
    private let meditationService: MeditationService
    private let selectionStore: MeditationSelectionStore

    init(meditationService: MeditationService,
         selectionStore: MeditationSelectionStore) {
        self.meditationService = meditationService
        self.selectionStore = selectionStore
    }

    func lastSelectedMeditation() -> Meditation? {
        guard let id = selectionStore.lastSelectedID else { return nil }
        return meditationService.getMeditations().first(where: { $0.id == id })
    }
}
