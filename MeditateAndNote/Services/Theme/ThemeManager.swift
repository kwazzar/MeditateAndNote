//
//  ThemeManager.swift
//  MeditateAndNote
//
//  Created by kwazzar on 16.08.2026.
//

import SwiftUI
import Observation
import MeditateAndNoteCore

@MainActor
@Observable
final class ThemeManager {
    private static let storageKey = "selectedMainTheme"

    private let logger = Logger(subsystem: "MeditateAndNote", category: "ThemeManager")
    private let defaults: UserDefaults
    private let eventBus: any DomainEventPublisher
    /// Premium read for theme gating. `nil` (previews/tests) leaves every
    /// theme selectable — gating is enforced only when wired in production.
    private let entitlements: (any EntitlementProviding)?
    /// `.subscriptionChanged` listener: a mid-session revoke must revert a
    /// rendered premium theme, not wait for the next launch. Unsafe: only
    /// MainActor mutates it; deinit (nonisolated) reads it to unsubscribe.
    private nonisolated(unsafe) var subscriptionToken: UUID?

    var current: MainTheme {
        didSet {
            defaults.set(current.rawValue, forKey: Self.storageKey)
        }
    }

    init(
        entitlements: (any EntitlementProviding)? = nil,
        defaults: UserDefaults = .standard,
        eventBus: any DomainEventPublisher = DomainEventBus.shared
    ) {
        self.entitlements = entitlements
        self.defaults = defaults
        self.eventBus = eventBus
        let savedRawValue = defaults.string(forKey: Self.storageKey)
        if let savedRawValue, MainTheme(rawValue: savedRawValue) == nil {
            logger.warning("Unknown stored theme '\(savedRawValue)' — falling back to default")
        }
        // A persisted premium theme outlives a downgrade: clamp to the free
        // default so a lapsed user never renders a locked theme.
        let resolved = MainTheme(rawValue: savedRawValue ?? "") ?? .darkZen
        self.current = Self.clampIfLocked(resolved, entitlements: entitlements)
        // Subscribe only after every stored property is initialized — the
        // escaping handler captures `self`.
        subscriptionToken = eventBus.subscribe { [weak self] event in
            guard case .subscriptionChanged = event else { return }
            Task { @MainActor [weak self] in
                self?.clampCurrentIfLocked()
            }
        }
    }

    deinit {
        if let subscriptionToken {
            eventBus.unsubscribe(subscriptionToken)
        }
    }

    /// True when the theme needs premium and the entitlement isn't active.
    /// No provider attached (previews/tests) → nothing is locked.
    func isLocked(_ theme: MainTheme) -> Bool {
        guard let entitlements else { return false }
        return theme.isPremium && !entitlements.isActive(.pro)
    }

    /// The only sanctioned mutation path: locked themes are refused (the UI
    /// routes the tap to the paywall instead).
    func select(_ theme: MainTheme) {
        guard !isLocked(theme) else {
            logger.info("Theme '\(theme.rawValue)' locked — premium required")
            return
        }
        current = theme
    }

    /// Runtime counterpart of the init-time clamp: the publisher fires after
    /// `SubscriptionManager.status` is updated, so this reads fresh state.
    private func clampCurrentIfLocked() {
        guard isLocked(current) else { return }
        logger.info("Entitlement revoked while '\(current.rawValue)' active — reverting to free theme")
        current = .darkZen
    }

    private static func clampIfLocked(
        _ theme: MainTheme,
        entitlements: (any EntitlementProviding)?
    ) -> MainTheme {
        guard let entitlements, theme.isPremium, !entitlements.isActive(.pro) else { return theme }
        return .darkZen
    }
}
