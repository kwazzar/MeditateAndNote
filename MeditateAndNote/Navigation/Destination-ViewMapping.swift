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
                .onAppear {
                    print("Creating NoteView for newNote")
                }

        case .meditationSettings:
            MeditateSelectView(viewModel: MeditateSelectViewModel())
                .onAppear {
                    print("Creating MeditateSelectView for meditationSettings")
                }

        case let .noteEditor(id):
            NoteView(viewModel: NoteViewModel())
                .onAppear {
                    print("Creating NoteView for noteEditor: \(id)")
                }
        }
    }
    .navigationBarTitleDisplayMode(.inline)
//    .presentationDetents([.medium, .large])
    .onAppear {
        print("Creating view for SheetDestination: \(destination)")
    }
}

@ViewBuilder func view(for destination: FullScreenDestination) -> some View {
    Group {
        switch destination {
        case let .meditationSession(id):

            MeditateSelectView(viewModel: MeditateSelectViewModel())
                .onAppear {
                    print("Creating MeditateSelectView for meditationSession: \(id)")
                    print("MeditateSelectView appeared in fullScreen")
                }

        case let .fullScreenNote(id):
            NoteView(viewModel: NoteViewModel())
                .onAppear {
                    print("Creating NoteView for fullScreenNote: \(id)")
                    print("NoteView appeared in fullScreen")
                }
        }
    }
    .onAppear {
        print("Creating view for FullScreenDestination: \(destination)")
    }

}

