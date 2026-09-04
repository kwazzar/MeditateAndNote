//
//  Destination-ViewMapping.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import SwiftUI

@ViewBuilder func view(for destination: PushDestination) -> some View {
    ContainerView { @MainActor container in
        Group {
            switch destination {
            case .newNote:
                NoteEditorView(viewModel: container.makeNoteEditorViewModel(noteId: nil))
            case let .noteDetails(noteId):
                NoteEditorView(viewModel: container.makeNoteEditorViewModel(noteId: noteId))
            case .readingView:
                ReadingView()
            case .meditation(_ : let meditation):
                MeditationView(viewModel: container.makeMeditationViewModel(for: meditation))
            case let .meditationCompletion(meditation, duration):
                MeditationCompletionView(meditation: meditation, duration: duration)
            case .streakDetail:
                StreakDetailView(
                    streakTracker: container.streakTracker,
                    insightsViewModel: container.makeInsightsViewModel()
                )
            case .settings:
                SettingsView(
                    animationSettings: container.animationSettings,
                    soundSettings: container.soundSettings,
                    container: container
                )
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

@ViewBuilder func view(for destination: SheetDestination) -> some View {
    ContainerView { @MainActor container in
        Group {
            switch destination {
            case .newNote:
                EmptyView()
            case .meditationSettings:
                EmptyView()
            case .timeMeditation:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        //    .presentationDetents([.medium, .large])
    }
}

@ViewBuilder func view(for destination: FullScreenDestination) -> some View {
    ContainerView { @MainActor container in
        Group {
            switch destination {
            case .meditationSession(_):
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case .fullScreenNote(_):
                EmptyView()
            }}
    }
}
