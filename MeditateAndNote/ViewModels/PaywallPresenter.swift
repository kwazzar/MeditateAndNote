//
//  PaywallPresenter.swift
//  MeditateAndNote
//

import Foundation
import Observation

/// Shared paywall presentation flag. Any gated surface (locked theme tap,
/// exhausted free quota) calls `present()`; `RootContainer` hosts the single
/// full-screen cover. Views never present paywalls themselves.
@MainActor
@Observable
final class PaywallPresenter {
    var isPresented = false

    func present() {
        isPresented = true
    }
}
