//
//  AnalyticsScreenModifier.swift
//  MeditateAndNote
//

import SwiftUI

private struct AnalyticsScreenModifier: ViewModifier {
    @Environment(\.appContainer) private var container
    let name: String

    func body(content: Content) -> some View {
        content.onAppear {
            container.analyticsTracker.trackScreen(name)
        }
    }
}

extension View {
    func analyticsScreen(_ name: String) -> some View {
        modifier(AnalyticsScreenModifier(name: name))
    }
}
