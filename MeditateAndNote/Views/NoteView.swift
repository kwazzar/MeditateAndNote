//
//  NoteView.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.03.2025.
//

import SwiftUI

struct NoteView: View {
    @State private var noteText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Note")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("Write your note here...")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }

                TextEditor(text: $noteText)
                    .font(.body)
                    .padding(12)
                    .frame(minHeight: 300)
                    .background(Color.white)
                    .opacity(noteText.isEmpty ? 0.25 : 1)
            }
            .padding(.horizontal)

            Spacer()

            Button(action: saveNote) {
                Text("Save Note")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func saveNote() {
        print("Note saved: \(noteText)")
    }
}

struct NoteView_Previews: PreviewProvider {
    static var previews: some View {
        NoteView()
    }
}
