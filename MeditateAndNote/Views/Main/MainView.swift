//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @EnvironmentObject var router: Router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StreakTracker.self) private var streakTracker

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                meditateButton
                Spacer()
            }
            Spacer()
        }
        .background(themeManager.current.mainBackground)
        .overlay(alignment: .top) {
            StreakHeaderView(streakTracker: streakTracker)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }
}

// MARK: - Extension
private extension MainView {
    var meditateButton: some View {
        Button(action: {
            do {
                router.navigate(to: .push(.meditation(try viewModel.getMeditation())))
            } catch {
                print(error)
            }
        }) {
            themeManager.current.meditateIcon
        }
        .buttonStyle(themeManager.current.meditateButtonStyle)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let localDataSource = UserDefaultsNoteDataSource()
        let noteRepository = DefaultNoteRepository(dataSource: localDataSource)
        let streakTracker = StreakTracker()

        MainView(viewModel: MainViewModel(meditationService: SampleMeditationService(), noteRepository: noteRepository))
            .environmentObject(Router.previewRouter())
            .environment(ThemeManager())
            .environment(streakTracker)
    }
}
