//
//  AnimationSettings.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation
import Observation
import MeditateAndNoteCore

//MARK: - AnimationSettings

/// Persisted meditation-animation preference. Mirrors the `SoundSettings` /
/// `ThemeManager` pattern: an observable value backed by `UserDefaults`,
@MainActor
/// injected as a singleton via `shared`.
@Observable
final class AnimationSettings {
    static let shared = AnimationSettings()

    static let storageKey = "meditationAnimationStyle"

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "MeditateAndNote", category: "AnimationSettings")
    private let eventBus: any DomainEventPublisher
    /// Premium read for animation gating. `nil` (previews/tests) leaves every
    /// style selectable; production attaches the subscription manager once.
    private var entitlements: (any EntitlementProviding)?
    /// `.subscriptionChanged` listener: a mid-session revoke must revert a
    /// rendered premium style, not wait for the next launch. Unsafe: only
    /// MainActor mutates it; deinit (nonisolated) reads it to unsubscribe.
    private nonisolated(unsafe) var subscriptionToken: UUID?

    var style: BreathingAnimationStyle {
        get { storedStyle }
        set { storedStyle = newValue }
    }

    private var storedStyle: BreathingAnimationStyle {
        didSet {
            defaults.set(storedStyle.rawValue, forKey: Self.storageKey)
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
        if let savedRawValue, BreathingAnimationStyle(rawValue: savedRawValue) == nil {
            logger.warning("Unknown stored animation style '\(savedRawValue)' — falling back to default")
        }
        // A persisted premium style outlives a downgrade: clamp to the free
        // default so a lapsed user never renders a locked animation.
        let resolved = BreathingAnimationStyle(rawValue: savedRawValue ?? "") ?? .path
        self.storedStyle = Self.clampIfLocked(resolved, entitlements: entitlements)
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

    /// Production wiring: the `.shared` singleton can't take the provider in
    /// init, so the app root attaches it once. Re-clamps a persisted premium
    /// style in case the entitlement lapsed since the last launch.
    func attachEntitlements(_ provider: any EntitlementProviding) {
        entitlements = provider
        if isLocked(storedStyle) {
            storedStyle = .path
        }
    }

    /// Runtime counterpart of the init-time clamp: the publisher fires after
    /// `SubscriptionManager.status` is updated, so this reads fresh state.
    private func clampCurrentIfLocked() {
        guard isLocked(storedStyle) else { return }
        logger.info("Entitlement revoked while '\(storedStyle.rawValue)' active — reverting to free animation")
        storedStyle = .path
    }

    /// True when the style needs premium and the entitlement isn't active.
    /// No provider attached (previews/tests) → nothing is locked.
    func isLocked(_ style: BreathingAnimationStyle) -> Bool {
        guard let entitlements else { return false }
        return style.isPremium && !entitlements.isActive(.pro)
    }

    /// The only sanctioned mutation path: locked styles are refused (the UI
    /// routes the tap to the paywall instead).
    func select(_ style: BreathingAnimationStyle) {
        guard !isLocked(style) else {
            logger.info("Animation '\(style.rawValue)' locked — premium required")
            return
        }
        storedStyle = style
    }

    private static func clampIfLocked(
        _ style: BreathingAnimationStyle,
        entitlements: (any EntitlementProviding)?
    ) -> BreathingAnimationStyle {
        guard let entitlements, style.isPremium, !entitlements.isActive(.pro) else { return style }
        return .path
    }
}
