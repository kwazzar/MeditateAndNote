//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct MainView: View {
    @State var viewModel: MainViewModel
    @EnvironmentObject var router: Router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StreakTracker.self) private var streakTracker

    var body: some View {
        VStack(spacing: 0) {
            StreakHeaderView(streakTracker: streakTracker)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            HStack {
                Spacer()
                meditateButton
                Spacer()
            }

            Spacer()
        }
        .overlay(alignment: .bottomTrailing) {
            settingsButton
                .padding(.bottom, 60)
                .padding(.trailing, 26)
        }
        .background(themeManager.current.mainBackground)
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
            .foregroundColor(.black)
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
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
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
            .environmentObject(Router.previewRouter())
            .environment(ThemeManager())
            .environment(StreakTracker())
    }
}
