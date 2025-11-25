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
            case .meditationDetails(_):
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case .noteDetails(let id):
                NoteView(viewModel: container.makeNoteViewModel(noteId: id))
            case .readingView(_):
                ReadingView()
            case .meditation(id: let id):
                MeditationView(viewModel: container.makeMeditationViewModel(id: id))
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
                NoteView(viewModel: container.makeNoteViewModel())
            case .meditationSettings:
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case .noteEditor(_):
                NoteView(viewModel: container.makeNoteViewModel())
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
                NoteView(viewModel: container.makeNoteViewModel())
            }
        }
    }
}
