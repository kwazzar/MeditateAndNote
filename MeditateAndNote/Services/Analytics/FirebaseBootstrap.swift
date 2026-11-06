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

    /// Configures the default Firebase app when the config file is present
    /// and valid. The file is gitignored on this public repo, so a clone
    /// without it still launches and analytics stays a no-op.
    static func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: path),
              let apiKey = options.apiKey,
              isUsable(
                  apiKey: apiKey,
                  appID: options.googleAppID,
                  bundleID: options.bundleID,
                  expectedBundleID: Bundle.main.bundleIdentifier ?? ""
              )
        else { return }
        FirebaseApp.configure(options: options)
        isConfigured = true
    }

    /// Whether the config file is one Firebase will accept.
    ///
    /// Firebase checks the API key and the app id itself and raises an
    /// Objective-C exception when they are wrong - Swift cannot catch that,
    /// so the app would die at launch. A placeholder file or a config from
    /// another project is skipped instead: analytics stays off, the app keeps
    /// running.
    ///
    /// The rules are Firebase's own: the key is 39 characters and starts with
    /// "AIza", the app id is `1:<number>:ios:<hash>`, and the bundle id has
    /// to be the one this app was built with.
    static func isUsable(
        apiKey: String,
        appID: String,
        bundleID: String,
        expectedBundleID: String
    ) -> Bool {
        guard apiKey.hasPrefix("AIza"), apiKey.count == 39 else { return false }
        guard !appID.isEmpty else { return false }
        if appID.contains(":") {
            guard appID.split(separator: ":").count == 4 else { return false }
        }
        guard bundleID == expectedBundleID else { return false }
        return true
    }
}
