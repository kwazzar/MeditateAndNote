//
//  MeditationService.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import Foundation

final class MeditationService: ObservableObject {
    private let meditations = [
        Meditation(id: "1", title: "Ранкова медитація", duration: 600),
        Meditation(id: "2", title: "Вечірня медитація", duration: 900),
        Meditation(id: "3", title: "Швидка медитація", duration: 300)
    ]

    func getMeditations() -> [Meditation] {
        return meditations
    }

    func getMeditation(id: String) -> Meditation? {
        return meditations.first { $0.id == id }
    }
}
