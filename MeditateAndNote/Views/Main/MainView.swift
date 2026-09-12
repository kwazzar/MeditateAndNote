//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct MainView: View {
    @State var viewModel: MainViewModel
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StreakTracker.self) private var streakTracker

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                themeManager.current.mainBackground

                VStack {
                    StreakHeaderView(streakTracker: streakTracker)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(maxWidth: HomeLayout.compactWidth)

                    Spacer()
                }

                meditateButton
                    .scaleEffect(isLandscape ? 0.7 : 1)

                settingsButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, isLandscape ? 52 : 60)
                    .padding(.trailing, 26)
            }
        }
    }
}

// MARK: - Extension
private extension MainView {
    var settingsButton: some View {
        Button(action: {
            router.navigate(to: .push(.settings))
        }) {
            HStack(spacing: 6) {
                Text("Settings")
                    .font(.headline)
            }
            .foregroundColor(themeManager.current.textPrimary)
            .frame(height: 40)
            .padding(5)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .gray.opacity(0.3), radius: 5)
            )
            .overlay(
                Capsule()
                    .strokeBorder(themeManager.current.dividerColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    var meditateButton: some View {
        Button(action: {
            if let meditation = viewModel.lastSelectedMeditation() {
                router.navigate(to: .push(.meditation(meditation)))
            }
        }) {
            themeManager.current.meditateIcon
        }
        .buttonStyle(themeManager.current.meditateButtonStyle)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewModel: MainViewModel(
            meditationService: SampleMeditationService(),
            selectionStore: MeditationSelectionStore()
        ))
            .environment(Router.previewRouter())
            .environment(ThemeManager())
            .environment(StreakTracker())
    }
}
