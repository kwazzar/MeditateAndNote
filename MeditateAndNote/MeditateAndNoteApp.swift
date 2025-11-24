//
//  MeditateAndNoteApp.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

@main
struct MeditateAndNoteApp: App {
    @StateObject private var router = Router(level: 0, identifierTab: nil)
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environmentObject(router)
                .environmentObject(container)
        }
    }
}
