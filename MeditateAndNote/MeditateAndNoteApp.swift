//
//  MeditateAndNoteApp.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

@main
struct MeditateAndNoteApp: App {
    @State private var router = Router(level: 0, identifierTab: nil)
    @State private var container = AppContainer.shared
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environment(router)
                .environment(\.appContainer, container)
                .environment(themeManager)
                .environment(container.streakTracker)
                .environment(container.meditationSessionStore)
                .environment(container.reminderManager)
        }
    }
}
