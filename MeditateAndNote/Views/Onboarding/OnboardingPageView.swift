//
//  OnboardingPageView.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import SwiftUI

/// A single onboarding slide: artwork placeholder + title + description.
/// Renders one `OnboardingPage`; all paging logic lives in `OnboardingViewModel`.
struct OnboardingPageView: View {
    let page: OnboardingPage

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            artwork
                .frame(height: 220)

            Text(page.title)
                .font(.title.bold())
                .foregroundStyle(themeManager.current.textPrimary)

            Text(page.subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(themeManager.current.textSecondary)
                .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    /// TODO: replace the SF Symbol placeholder with per-theme animated artwork
    /// (see `MainTheme.meditateIcon` for the existing `@ViewBuilder` pattern).
    private var artwork: some View {
        Image(systemName: page.systemImage)
            .font(.system(size: 100, weight: .thin))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(themeManager.current.iconPrimary)
    }
}

struct OnboardingPageView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPageView(page: OnboardingPage.appSlides[0])
            .environment(ThemeManager())
    }
}