//
//  MeditateAndNoteApp.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import FirebaseCore
import SwiftUI

@main
struct MeditateAndNoteApp: App {
    @State private var router = Router(level: 0, identifierTab: nil)
    @State private var container = AppContainer.shared
    @State private var themeManager = ThemeManager(entitlements: AppContainer.shared.subscriptionManager)

    init() {
        // The config is gitignored on this public repo, so a clone without it
        // still launches (analytics stays a no-op).
        FirebaseBootstrap.configureIfNeeded()

        // The `.shared` settings singletons can't take the provider in init,
        // so the app root attaches the premium read once at launch.
        AnimationSettings.shared.attachEntitlements(AppContainer.shared.subscriptionManager)
    }

    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environment(router)
                .environment(\.appContainer, container)
                .environment(themeManager)
                .environment(container.streakTracker)
                .environment(container.meditationSessionStore)
                .environment(container.reminderManager)
                .environment(container.subscriptionManager)
        }
    }
}
