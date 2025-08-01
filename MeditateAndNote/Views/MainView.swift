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

    var body: some View {
        VStack {
            CloudParametersView()
                .innerStroke()
            Spacer()
            HStack {
                Button(action: {
                    router.navigate(to: .push(.meditationDetails(id: "left wing")))
                }) {
                    Text("Meditation")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .fixedSize()
                        .rotationEffect(.degrees(90))
                        .frame(width: 40, height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                        )
                }
                .innerStroke(inset: 1)
                .padding(.leading, -4)

                Spacer()
                meditateButton
                Spacer()

                Button(action: {
                    router.navigate(to: .sheet(.newNote))
                }) {
                    Text("New Note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 40, height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                        )
                }
                .innerStroke(inset: 1)
                .padding(.trailing, -4)
            }
            Spacer()
            NoteCardsView(noteCards: viewModel.last10Notes)
        }
        .background(.green)
    }
}

// MARK: - Extension
private extension MainView {
    var meditateButton: some View {
        Button(action: {
//            router.navigate(to: .fullScreen(.meditationSession(id: "main")))
            router.navigate(to: .push(.meditationDetails(id: "meditate")))
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
        MainView(viewModel: AppContainer().makeMainViewModel())
    }
}
