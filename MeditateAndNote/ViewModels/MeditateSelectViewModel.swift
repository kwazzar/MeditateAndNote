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

final class MeditateSelectViewModel: ObservableObject {
    private enum LoadState {
        case loading
        case loaded([Meditation])
    }

    @Published private var loadState: LoadState = .loading
    @Published var selectedMeditation: Meditation? = nil
    @Published var infoItem: MeditationInfoItem?

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
        loadState = .loading

        // Simulate loading with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
