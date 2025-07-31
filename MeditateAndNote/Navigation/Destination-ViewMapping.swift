//
//  Destination-ViewMapping.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import SwiftUI

@ViewBuilder func view(for destination: TabDestination) -> some View {
    ContainerView { container in
        switch destination {
        case .home:
             MainView(viewModel: container.makeMainViewModel())
        }
    }
}

@ViewBuilder func view(for destination: PushDestination) -> some View {
    ContainerView { container in
        Group {
            switch destination {
            case .meditationDetails(let id):
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case .noteDetails(let id):
                NoteView(viewModel: container.makeNoteViewModel())
            case .readingView(let id):
                ReadingView()
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
            case let .noteEditor(id):
                NoteView(viewModel: container.makeNoteViewModel())
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
            case let .meditationSession(id):
                MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
            case let .fullScreenNote(id):
                NoteView(viewModel: container.makeNoteViewModel())
            }
        }
    }
}
