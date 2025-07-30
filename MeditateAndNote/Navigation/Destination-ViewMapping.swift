//
//  Destination-ViewMapping.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import SwiftUI

@ViewBuilder func view(for destination: PushDestination) -> some View {
    switch destination {
    case .meditationDetails(let id):
        MeditateSelectView(viewModel: MeditateSelectViewModel())
    case .noteDetails(let id):
        NoteView(viewModel: NoteViewModel())
    case .readingView(let id):
        ReadingView()
    }
}

@ViewBuilder func view(for destination: SheetDestination) -> some View {
    Group {
        switch destination {
        case .newNote:
            NoteView(viewModel: NoteViewModel())
        case .meditationSettings:
            MeditateSelectView(viewModel: MeditateSelectViewModel())
        case let .noteEditor(id):
            NoteView(viewModel: NoteViewModel())
        }
    }
    .navigationBarTitleDisplayMode(.inline)
//    .presentationDetents([.medium, .large])
}

@ViewBuilder func view(for destination: FullScreenDestination) -> some View {
    Group {
        switch destination {
        case let .meditationSession(id):
            MeditateSelectView(viewModel: MeditateSelectViewModel())

        case let .fullScreenNote(id):
            NoteView(viewModel: NoteViewModel())
        }
    }
}
