//
//  MainViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    @Published var visibleNotes: [Note] = MockNotes
    let last10Notes: [Note]

    init(visibleNotes: [Note]) {
        self.visibleNotes = visibleNotes

        last10Notes = Array(visibleNotes.suffix(10))
    }
}
