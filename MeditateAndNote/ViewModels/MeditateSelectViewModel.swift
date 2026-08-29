//
//  MeditateSelectViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation

/// Presentation value behind the info sheet. Distinct from the selected
/// meditation so the view model never holds two optionals of the same type
/// and can't confuse "real" selection with an on-screen info modal.
struct MeditationInfoItem: Identifiable, Equatable {
    let meditation: Meditation

    var id: MeditationID { meditation.id }
}

@MainActor
@Observable
final class MeditateSelectViewModel {
    private enum LoadState {
        case loading
        case loaded([Meditation])
    }

    private var loadState: LoadState = .loading
    var selectedMeditation: Meditation? = nil
    var infoItem: MeditationInfoItem?

    private var loadTask: Task<Void, Never>?

    var meditations: [Meditation] {
        guard case .loaded(let items) = loadState else { return [] }
        return items
    }

    private let meditationService: MeditationService
    private let selectionStore: MeditationSelectionStore

    init(meditationService: MeditationService,
         selectionStore: MeditationSelectionStore = MeditationSelectionStore()) {
        self.meditationService = meditationService
        self.selectionStore = selectionStore
        loadMeditations()
    }

    func loadMeditations() {
        loadTask?.cancel()
        loadState = .loading

        // Simulate loading with sample data
        loadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.loadState = .loaded(self.meditationService.getMeditations())
            self.restoreLastSelectedMeditation()
        }
    }
    
    func selectMeditation(_ meditation: Meditation) {
        selectedMeditation = meditation
        infoItem = nil
        saveLastSelectedMeditation(meditation)
    }
    
    func startMeditation() {
        if selectedMeditation == nil, let first = meditations.first {
            selectMeditation(first)
        }
    }
    
    func saveLastSelectedMeditation(_ meditation: Meditation) {
        selectionStore.lastSelectedID = meditation.id
    }

    private func restoreLastSelectedMeditation() {
        guard let lastSelectedID = selectionStore.lastSelectedID,
              let lastMeditation = meditations.first(where: { $0.id == lastSelectedID }) else {
            if let first = meditations.first {
                selectedMeditation = first
                saveLastSelectedMeditation(first)
            }
            return
        }
        selectedMeditation = lastMeditation
    }
}
