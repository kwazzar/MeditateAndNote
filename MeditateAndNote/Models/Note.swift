//
//  Note.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

struct Note: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let content: String
    let date: Date
}
