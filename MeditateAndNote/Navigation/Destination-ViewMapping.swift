//
//  Destination-ViewMapping.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import SwiftUI

@ViewBuilder func view(for destination: PushDestination) -> some View {
    ContainerView { container in
        Group {
            switch destination {
            case .noteDetails(let noteId, _):
                NoteEditorView(viewModel: container.makeNoteEditorViewModel(noteId: noteId))
            case .readingView(_):
                ReadingView()
            case .meditation(_ : let meditation):
                MeditationView(viewModel: container.makeMeditationViewModel(for: meditation))
            case .streakDetail:
                StreakDetailView(streakTracker: container.streakTracker)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

@ViewBuilder func view(for destination: SheetDestination) -> some View {
    ContainerView { container in
        Group {
            switch destination {
            case .newNote:
                EmptyView()
            case .meditationSettings:
                EmptyView()
            case .noteEditor(_):
                EmptyView()
            case let .timeMeditation(onSelection):
                TimeMeditationSheet(onSelection: onSelection)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        //    .presentationDetents([.medium, .large])
    }
}

@ViewBuilder func view(for destination: FullScreenDestination) -> some View {
    ContainerView { container in
        Group {
            switch destination {
            case .meditationSession(_):
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case .fullScreenNote(_):
                EmptyView()
            }
        }
    }
}
