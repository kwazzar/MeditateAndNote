//
//  MeditateAndNoteDetails.swift
//  MeditateAndNote
//
//  Created by Quasar on 20.07.2025.
//

import Foundation   

public typealias MeditationID = String
public typealias NoteID = String

public struct MeditationDetails {
    public let id: MeditationID
    public let title: String
    public let duration: TimeInterval
    public let description: String?
}

public struct NoteDetails {
    public let id: NoteID
    public let title: String
    public let content: String
    public let date: Date
}
