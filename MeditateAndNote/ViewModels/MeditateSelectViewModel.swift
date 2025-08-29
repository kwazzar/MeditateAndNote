//
//  MeditateSelectViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation

final class MeditateSelectViewModel: ObservableObject {
    @Published var meditations: [Meditation] = []
    @Published var selectedMeditation: Meditation? = nil
    @Published var isLoading = false
    
    private let meditationService: MeditationService
    private let lastSelectedKey = "lastSelectedMeditationId"
    
    init(meditationService: MeditationService) {
        self.meditationService = meditationService
        loadMeditations()
        
    }
    
    func loadMeditations() {
        isLoading = true
        
        // Simulate loading with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.meditations = self.meditationService.getMeditations()
            self.restoreLastSelectedMeditation()
            self.isLoading = false
        }
    }
    
    func selectMeditation(_ meditation: Meditation) {
        selectedMeditation = meditation
        saveLastSelectedMeditation(meditation)
    }
    
    func startMeditation() {
        if selectedMeditation == nil, let first = meditations.first {
            selectMeditation(first)
        }
    }
    
    func saveLastSelectedMeditation(_ meditation: Meditation) {
        UserDefaults.standard.set(meditation.id, forKey: lastSelectedKey)
        
    }
    
    private func restoreLastSelectedMeditation() {
        guard let lastSelectedId = UserDefaults.standard.string(forKey: lastSelectedKey),
              let lastMeditation = meditations.first(where: { $0.id == lastSelectedId }) else {
            if let first = meditations.first {
                selectedMeditation = first
                saveLastSelectedMeditation(first)
            }
            return
        }
        selectedMeditation = lastMeditation
    }
}
