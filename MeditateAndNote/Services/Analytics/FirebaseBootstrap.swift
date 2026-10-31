//
//  FirebaseBootstrap.swift
//  MeditateAndNote
//

import FirebaseCore
import Foundation

/// Owns the Firebase lifecycle for the app.
///
/// `FirebaseApp.app()` and `FirebaseApp.allApps` both log an error when no
/// app is configured yet, so neither can be used as a "is it ready?" check
/// before `configure()` ran. This flag is that check.
enum FirebaseBootstrap {

    private(set) nonisolated(unsafe) static var isConfigured = false

    /// Configures the default Firebase app when the config file is present.
    /// The file is gitignored on this public repo, so a clone without it
    /// still launches and analytics stays a no-op.
    static func configureIfNeeded() {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        isConfigured = true
    }
}
