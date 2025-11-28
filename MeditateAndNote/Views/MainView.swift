//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI
#warning("UI")
#warning("1meditate 2(read <-> note)3")
struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @EnvironmentObject var router: Router

    var body: some View {
        VStack {
            CloudParametersView()
                .innerStroke()
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
        .background(.green)
    }
}

// MARK: - Extension
private extension MainView {
    var meditateButton: some View {
        Button(action: {
            let lastSelectedId = UserDefaults.standard.string(forKey: "lastSelectedMeditationId") ?? "default_meditation_id"

            router.navigate(to: .push(.meditation(id: lastSelectedId)))
        }) {
            Circle()
                .fill(Color.blue)
                .frame(width: 200, height: 200)
                .overlay(
                    Text("M")
                        .foregroundColor(.white)
                        .font(.system(size: 150))
                )
                .shadow(radius: 5)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewModel: MainViewModel(notesService: NotesService()))
            .environmentObject(Router.previewRouter())
    }
}
