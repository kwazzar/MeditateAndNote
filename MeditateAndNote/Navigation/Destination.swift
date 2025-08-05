//
//  Destination.swift
//  MeditateAndNote
//
//  Created by Quasar on 20.07.2025.
//

import Foundation

public enum Destination: Hashable {
    case tab(_ destination: TabDestination)
    case push(_ destination: PushDestination)
    case sheet(_ destination: SheetDestination)
    case fullScreen(_ destination: FullScreenDestination)
}

extension Destination: CustomStringConvertible {
    public var description: String {
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

public enum PushDestination: Hashable, CustomStringConvertible {
    case meditationDetails(id: String)
    case noteDetails(id: String)
    case readingView(id: String)
    case meditation(id: String)

    public var description: String {
        switch self {
        case let .meditationDetails(id): 
            return ".meditationDetails(\(id))"
        case let .noteDetails(id): 
            return ".noteDetails(\(id))"
        case let .readingView(id): 
            return ".readingView(\(id))"
        case .meditation(id: let id):
            return ".meditation(\(id))"
        }
    }
}

public enum TabDestination: String, Hashable {
    case home
}

public enum SheetDestination: Hashable, CustomStringConvertible {
    case newNote
    case meditationSettings
    case noteEditor(id: String)
    case timeMeditation(onSelection: (MeditationDuration) -> Void)

    public var description: String {
        switch self {
        case .newNote: 
            return ".newNote"
        case .meditationSettings: 
            return ".meditationSettings"
        case let .noteEditor(id): 
            return ".noteEditor(\(id))"
        case .timeMeditation:
            return ".timeMeditation"
        }
    }

    public static func == (lhs: SheetDestination, rhs: SheetDestination) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SheetDestination: Identifiable {
    public var id: String {
        switch self {
        case .newNote: 
            return "newNote"
        case .meditationSettings: 
            return "meditationSettings"
        case let .noteEditor(id): 
            return "noteEditor_\(id)"
        case .timeMeditation:
            return ".timeMeditation"
        }
    }
}

public enum FullScreenDestination: Hashable {
    case meditationSession(id: String)
    case fullScreenNote(id: String)
}

extension FullScreenDestination: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .meditationSession(id): 
            return ".meditationSession(\(id))"
        case let .fullScreenNote(id): 
            return ".fullScreenNote(\(id))"
        }
    }
}

extension FullScreenDestination: Identifiable {
    public var id: String {
        switch self {
        case let .meditationSession(id): 
            return "meditationSession_\(id)"
        case let .fullScreenNote(id): 
            return "fullScreenNote_\(id)"
        }
    }
}
