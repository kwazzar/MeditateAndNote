//
//  MockNotes.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import Foundation

 let MockNotes: [Note] = [
    Note(
        title: "Project Planning",
        content: "Meeting with the development team to discuss new features. We need to focus on improving user experience and implementing better error handling. The timeline for this sprint will be approximately 2 weeks with daily standups at 10 AM.",
        date: Date()
    ),
    Note(
        title: "Research Notes",
        content: "Latest findings indicate that users prefer simplified navigation patterns. Key points: 1) Minimize nested menus 2) Keep important actions visible 3) Provide clear feedback for all interactions 4) Maintain consistency across platforms.",
        date: Date().addingTimeInterval(-86400)
    ),
    Note(
        title: "Interview Questions",
        content: "Prepare technical questions for junior developer position: 1) Experience with Swift and SwiftUI 2) Understanding of MVVM architecture 3) Knowledge of Git workflow 4) Previous experience with unit testing and UI testing.",
        date: Date().addingTimeInterval(-172800)
    ),
    Note(
        title: "Bug Tracking",
        content: "Critical issues found in latest release: 1) App crashes when loading large images 2) Authentication token not refreshing properly 3) Memory leak in chat module 4) Performance issues in search functionality. Need immediate attention.",
        date: Date().addingTimeInterval(-259200)
    ),
    Note(
        title: "Feature Ideas",
        content: "New features for Q2 roadmap: 1) Implement dark mode support 2) Add offline data synchronization 3) Integrate with third-party analytics 4) Improve push notification system. Also consider adding machine learning capabilities for better user recommendations.",
        date: Date().addingTimeInterval(-345600)
    )
]
