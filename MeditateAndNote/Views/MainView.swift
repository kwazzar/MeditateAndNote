//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI
#warning("замість параметрів стрік")
#warning("UI")
#warning("1meditate 2(read <-> note)3")

var theme: MainScreenTheme = .breathing

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @EnvironmentObject var router: Router

    var body: some View {
        VStack {
//            CloudParametersView()
//                .innerStroke()
            Spacer()
            HStack {
                Spacer()
                meditateButton
                Spacer()
            }
            Spacer()

            #warning("week streak")
//            NoteCardsView(noteCards: viewModel.last10Notes)
//                .padding(.bottom, 12)
        }
        .background(theme.mainBackground)
    }
}

// MARK: - Extension
private extension MainView {
    var meditateButton: some View {
        Button(action: {
            let lastSelectedId = UserDefaults.standard.string(forKey: "lastSelectedMeditationId") ?? "default_meditation_id"

            router.navigate(to: .push(.meditation(id: lastSelectedId)))
        }) {
            theme.meditateIcon
        }
        .buttonStyle(theme.meditateButtonStyle)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        let repo = NotesRepository(
            localDataSource: UserDefaultsNotesRepository(),
            remoteDataSource: InMemoryNotesDataSource()
        )
        MainView(viewModel: MainViewModel(repository: repo))
            .environmentObject(Router.previewRouter())
    }
}
