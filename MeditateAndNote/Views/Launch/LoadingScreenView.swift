//
//  LoadingScreenView.swift
//  MeditateAndNote
//
//  Created by kwazzar on 07.09.2026.
//

import SwiftUI

/// Full-screen launch loader shown on every app entry.
/// Purely presentational: sources every color and the hero artwork from
/// `MainTheme`, so it matches whichever theme is active (all five themes).
struct LoadingScreenView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var isBreathing = false

    var body: some View {
        ZStack {
            themeManager.current.mainBackground

            // Hero sits in the exact screen center — the same position the
            // meditate button uses on the Main screen, so the splash morphs
            // into the tabs without the icon jumping.
            hero
                .scaleEffect(isBreathing ? 1.06 : 0.96)

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text("Meditate & Note")
                        .font(.title2.bold())
                        .foregroundStyle(themeManager.current.textPrimary)

                    ProgressView()
                        .tint(themeManager.current.accentColor)
                        .scaleEffect(0.9)
                }
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.4)
                    .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }

    /// Per-theme breathing hero: the same `meditateIcon` the Main screen uses,
    /// so the splash always feels like the app's own visual language.
    private var hero: some View {
        themeManager.current.meditateIcon
            .shadow(
                color: themeManager.current.accentColor.opacity(0.35),
                radius: 30, y: 8
            )
    }
}

struct LoadingScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingScreenView()
            .environment(ThemeManager())
    }
}