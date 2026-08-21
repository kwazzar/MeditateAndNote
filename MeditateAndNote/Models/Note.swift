//
//  Note.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

//MARK: - Value Types

struct NoteID: Hashable, Codable {
    let rawValue: UUID
    
    init() { self.rawValue = UUID() }
    init(rawValue: UUID) { self.rawValue = rawValue }
    
    static func == (lhs: NoteID, rhs: NoteID) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
    
    // Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuid = try container.decode(UUID.self)
        self.init(rawValue: uuid)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct MeditationTitle: Hashable, Codable {
    let rawValue: String
    
    init(_ rawValue: String) {
        self.rawValue = rawValue.isEmpty ? "Untitled" : rawValue
    }
}

extension MeditationTitle: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self.rawValue = value.isEmpty ? "Untitled" : value }
    init(extendedGraphemeClusterLiteral value: String) { self.rawValue = value.isEmpty ? "Untitled" : value }
    init(unicodeScalarLiteral value: String) { self.rawValue = value.isEmpty ? "Untitled" : value }
}

extension MeditationTitle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

//MARK: - Note

struct Note: Codable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case date
    }
    
    var id: NoteID
    var title: MeditationTitle
    var content: String
    var date: Date
    
    init(id: NoteID = NoteID(), title: MeditationTitle = MeditationTitle(""), content: String = "", date: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
    }
    
    // Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decode(UUID.self, forKey: .id)
        self.id = NoteID(rawValue: uuid)
        let titleString = try container.decode(String.self, forKey: .title)
        self.title = MeditationTitle(titleString)
        self.content = try container.decode(String.self, forKey: .content)
        self.date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.rawValue, forKey: .id)
        try container.encode(title.rawValue, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(date, forKey: .date)
    }
}

