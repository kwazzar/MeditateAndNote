//
//  NoteCardsView.swift
//  MeditateAndNote
//
//  Created by Quasar on 01.03.2025.
//

import SwiftUI

struct NoteCardsView: View {
    @State var noteCards: [Note]

    var body: some View {
        ZStack {
            ForEach(Array(noteCards.enumerated().reversed()), id: \.element.id) { index, note in
                NoteCard(note: note)
                    .offset(y: CGFloat(index) * 25)
                    .onTapGesture {
                        withAnimation {
                            if let noteIndex = noteCards.firstIndex(where: { $0.id == note.id }) {
                                let note = noteCards.remove(at: noteIndex)
                                noteCards.insert(note, at: 0)
                            }
                        }
                    }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, CGFloat(min(noteCards.count, 10)) * 20)
    }
}

struct NoteCardsView_Previews: PreviewProvider {
    static var previews: some View {
        NoteCardsView(noteCards: MockNotes)
    }
}
