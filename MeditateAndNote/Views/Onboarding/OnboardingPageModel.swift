//
//  OnboardingPageModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import Foundation

/// Data model of a single onboarding slide.
/// Pure presentation-layer value type: no layout, no side effects.
struct OnboardingPage: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    /// SF Symbol name used as placeholder artwork. Replace with themed
    /// animation when real artwork lands (see `MainTheme.meditateIcon`).
    let systemImage: String

    init(id: UUID = UUID(),
         title: String,
         subtitle: String,
         systemImage: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

// MARK: - Default content

extension OnboardingPage {
    /// Default slides for the first launch.
    ///
    /// TODO: finalize copy and swap SF Symbol placeholders for per-theme
    /// animated artwork once it is designed.
    static var appSlides: [OnboardingPage] {
        [
            OnboardingPage(
                title: "Meditations",
                subtitle: "Focus on your breathing with guided sessions and soothing animations.",
                systemImage: "leaf"
            ),
            OnboardingPage(
                title: "Notes",
                subtitle: "Capture your thoughts right after a session, while they are still fresh.",
                systemImage: "note.text"
            ),
            OnboardingPage(
                title: "Streak tracking",
                subtitle: "Build a habit: a daily meditation plus a note keeps your streak alive.",
                systemImage: "flame"
            ),
        ]
    }
}