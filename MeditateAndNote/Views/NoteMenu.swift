//
//  NoteMenu.swift
//  MeditateAndNote
//
//  Created by Quasar on 28.11.2025.
//

import SwiftUI
#warning("Note and Reading")
#warning("searcBar note")

enum Menu {
    case Note
    case Reading
}

struct NoteMenu: View {
    @StateObject var viewModel: NoteMenuViewModel

    var body: some View {
        VStack {
            HStack {

            }
            Spacer()
            NoteCardsView(noteCards: viewModel.last10Notes)
                .padding(.bottom, 12)

        }
        .background(Color.blue)

    }
}

struct NoteMenu_Previews: PreviewProvider {
    static var previews: some View {
        NoteMenu(viewModel: AppContainer().makeNoteMenuView())
    }
}
