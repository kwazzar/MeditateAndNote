//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

#warning("cоздать note view")
#warning("островки для кожної сторони")
#warning("свайп екрана вправо єто новая заметка")
#warning("свайп вправо вибір медитації")
struct MainView: View {
    @StateObject var viewModel: MainViewModel
    
    var body: some View {
        VStack {
            CloudParametersView()
            Spacer()
            HStack {
                Spacer()
                meditateButton
                Spacer()
#warning("LiquidSwipe")
                Button(action: {
                    // Действие для настроек
                }) {
                    Text("New Note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
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
#warning("последние 10 заметок")
#warning("при нажании на заметку она становится на первый план")
            noteCards
        }.background(.green)
    }
}

//MARK: - Extension
private extension MainView {
    
    var meditateButton: some View {
        Button(action: {
            
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
    
    var noteCards: some View {
        ZStack {
            ForEach(Array(viewModel.visibleNotes.enumerated().reversed()), id: \.element.id) { index, note in
                NoteCard(note: note)
                    .offset(y: CGFloat(index) * 25)
                    .onTapGesture {
                        withAnimation {
                            if let noteIndex = viewModel.visibleNotes.firstIndex(where: { $0.id == note.id }) {
                                let note = viewModel.visibleNotes.remove(at: noteIndex)
                                viewModel.visibleNotes.append(note)
                            }
                        }
                    }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, CGFloat(viewModel.visibleNotes.count) * 20)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(viewModel: MainViewModel())
    }
}
