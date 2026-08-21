//
//  Destination.swift
//  MeditateAndNote
//
//  Created by Quasar on 20.07.2025.
//

import Foundation
import SwiftUI

enum Destination: Hashable {
    case tab(_ destination: TabDestination)
    case push(_ destination: PushDestination)
    case sheet(_ destination: SheetDestination)
    case fullScreen(_ destination: FullScreenDestination)
}

extension Destination: CustomStringConvertible {
    var description: String {
        switch self {
        case let .tab(destination): 
            return ".tab(\(destination))"
        case let .push(destination): 
            return ".push(\(destination))"
        case let .sheet(destination): 
            return ".sheet(\(destination))"
        case let .fullScreen(destination): 
            return ".fullScreen(\(destination))"
        }
    }
}

enum PushDestination: Hashable, CustomStringConvertible {
    case newNote
    case noteDetails(noteId: NoteID)
    case readingView
    case meditation(_ meditation: Meditation)
    case streakDetail

    var description: String {
        switch self {
        case .newNote:
            return ".newNote"
        case let .noteDetails(noteId):
            return ".noteDetails(\(noteId))"
        case .readingView:
            return ".readingView"
        case let .meditation(meditation):
            return ".meditation(\(meditation))"
        case .streakDetail:
            return ".streakDetail"
        }
    }
}

enum TabDestination: String, Hashable {
    case home
    case notes
    case meditations
}

enum SheetDestination: Hashable, CustomStringConvertible {
    case newNote
    case meditationSettings
    case timeMeditation(onSelection: (MeditationDuration) -> Void)

    var description: String {
        switch self {
        case .newNote:
            return ".newNote"
        case .meditationSettings:
            return ".meditationSettings"
        case .timeMeditation:
            return ".timeMeditation"
        }
    }

    static func == (lhs: SheetDestination, rhs: SheetDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SheetDestination: Identifiable {
    var id: String {
        switch self {
        case .newNote:
            return "newNote"
        case .meditationSettings:
            return "meditationSettings"
        case .timeMeditation:
            return ".timeMeditation"
        }
    }
}

enum FullScreenDestination: Hashable {
    case meditationSession(id: MeditationID)
    case fullScreenNote(id: NoteID)
}

extension FullScreenDestination: CustomStringConvertible {
    var description: String {
        switch self {
        case let .meditationSession(id):
            return ".meditationSession(\(id))"
        case let .fullScreenNote(id):
            return ".fullScreenNote(\(id))"
        }
    }
}

extension FullScreenDestination: Identifiable {
    var id: String {
        switch self {
        case let .meditationSession(id):
            return "meditationSession_\(id)"
        case let .fullScreenNote(id):
            return "fullScreenNote_\(id)"
        }
    }
}

