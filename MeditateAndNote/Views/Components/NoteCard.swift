//
//  NoteCard.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct NoteCard: View {
    let note: Note
    let toNoteAction: (Note) -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Основное содержимое карточки
            VStack(alignment: .leading, spacing: 8) {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .frame(height: 120)
            .background(Color.white)

            // Нижняя панель с датой
            HStack {
                Text(dateFormatter.string(from: note.date))
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
                Text(note.title)
                    .font(.headline)
                Spacer()

                Button {
                    toNoteAction(note)
                   } label: {
                       Image(systemName: "chevron.right")
                           .foregroundColor(.black)
                   }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.black.opacity(0.2)),
                alignment: .top
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.black, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.2), radius: 5)
        )
    }
}
