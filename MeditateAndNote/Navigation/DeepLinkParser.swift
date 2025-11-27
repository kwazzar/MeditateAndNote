//
//  DeepLinkParser.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import Foundation

/// A function that matches a deep link URL to a destination if possible
struct DeepLinkParser {
    let parse: (URL) -> Destination?
}

extension URL {
    /// Split URL components without considering the scheme
    ///
    /// Example:
    ///
    /// for `meditateandnote://meditation/123` this returns
    ///
    /// ```swift
    /// ["meditation", "123"]
    /// ```
    var fullComponents: [String] {
        guard let scheme else { return [] }

        return absoluteString
            .replacingOccurrences(of: "\(scheme)://", with: "")
            .split(separator: "/")
            .map { String($0) }
    }
}

extension DeepLinkParser {
    static func equal(to components: [String], destination: Destination) -> Self {
        .init { url in
            guard url.fullComponents == components else { return nil }
            return destination
        }
    }

    static let meditationDetails: Self = .init { url in
        guard
            url.fullComponents.first == "meditation",
            let meditationID = url.fullComponents.last
        else { return nil }

        return .push(.meditationDetails(id: meditationID))
    }

//    static let noteDetails: Self = .init { url in
//        guard
//            url.fullComponents.first == "note",
//            let noteID = url.fullComponents.last
//        else { return nil }
//
//        return .push(.noteDetails(id: noteID))
//    }

    static let meditationSettings: Self = .init { url in
        guard
            url.fullComponents.first == "meditation",
            url.fullComponents.count == 2,
            url.fullComponents.last == "settings"
        else { return nil }

        return .sheet(.meditationSettings)
    }

    static let newNote: Self = .init { url in
        guard
            url.fullComponents.first == "note",
            url.fullComponents.count == 2,
            url.fullComponents.last == "new"
        else { return nil }

        return .sheet(.newNote)
    }
}
