//
//  MeditateSelectViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import Foundation

final class MeditateSelectViewModel: ObservableObject {
    @Published var meditations: [Meditation] = []
    @Published var selectedMeditation: Meditation?

    private let meditationService: MeditationService

    init(meditationService: MeditationService) {
        self.meditationService = meditationService
        loadMeditations()
    }

    private func loadMeditations() {
        meditations = meditationService.getMeditations()
    }

    func selectMeditation(_ meditation: Meditation) {
        selectedMeditation = meditation
    }
}
