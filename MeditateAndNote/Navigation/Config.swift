//
//  Config.swift
//  MeditateAndNote
//
//  Created by Quasar on 20.07.2025.
//

import Foundation
import MeditateAndNoteCore

public enum Config {
    public static let bundleID = LogSubsystem.main
    public static let deepLinkScheme: String = "meditateandnote"
    public static var revenueCatAPIKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String) ?? ""
    }
    /// The hosted AI provider (our proxy): it carries the provider key, so
    /// the app ships without one. Empty when the build names no provider —
    /// then the user brings their own endpoint.
    public static var aiDraftEndpoint: String {
        let value = (Bundle.main.object(forInfoDictionaryKey: "AIDraftEndpoint") as? String) ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static let proEntitlementID: String = "premium"
}
