//
//  Deeplink.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.07.2025.
//

import Foundation

public struct DeepLink {
    public static func destination(from url: URL) -> Destination? {
        guard url.scheme == Config.deepLinkScheme else { return nil }

        for parser in registeredParsers {
            if let destination = parser.parse(url) {
                return destination
            }
        }

        return nil
    }

    static let registeredParsers: [DeepLinkParser] = [
        .equal(to: ["home"], destination: .tab(.home)),
//        .equal(to: ["meditate"], destination: .tab(.meditate)),
//        .equal(to: ["notes"], destination: .tab(.notes)),
//        .equal(to: ["reading"], destination: .tab(.reading)),

        .equal(to: ["meditation", "new"], destination: .sheet(.meditationSettings)),
        .equal(to: ["note", "new"], destination: .sheet(.newNote)),
    ]
}
