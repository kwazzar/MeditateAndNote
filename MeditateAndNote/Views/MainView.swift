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

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @EnvironmentObject var router: Router
    @Environment(ThemeManager.self) private var themeManager

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
        .background(themeManager.current.mainBackground)
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
        let repo = NotesRepository(
            localDataSource: UserDefaultsNotesRepository(),
            remoteDataSource: InMemoryNotesDataSource()
        )
        MainView(viewModel: MainViewModel(meditationService: SampleMeditationService(), repository: repo))
            .environmentObject(Router.previewRouter())
    }
}
