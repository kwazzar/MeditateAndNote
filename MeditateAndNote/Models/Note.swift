//
//  Note.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var content: String
    var date: Date
}
