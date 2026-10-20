//
//  HostedProviderSettings.swift
//  MeditateAndNote
//
//  Where the drafts are answered: the hosted provider (our proxy, which
//  carries the provider key) or an endpoint of the user's own.
//
//  The contract lives in the app, not in Core: the Core store contract is
//  bridged to Java by jextract, and a new requirement there means
//  regenerating those bindings. The choice is a deployment decision rather
//  than a domain rule, so it has no business in the shared core.
//

import Foundation
import MeditateAndNoteCore

protocol HostedProviderSettings: AIDraftSettingsStore {
    /// Whether the hosted provider answers the drafts. A build that names a
    /// hosted endpoint says yes until the user says otherwise.
    func useHostedProvider() -> Bool
    /// The user's answer to that question.
    func setUseHostedProvider(_ value: Bool)
}
