//
//  NoteViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 03.03.2025.
//

import SwiftUI

final class NoteViewModel: ObservableObject {
    @Published var noteText: String = ""

    func saveNote() {
        print("Note saved: \(noteText)")
    }
}
