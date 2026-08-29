//
//  ContainerView.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import SwiftUI

struct ContainerView<Content: View>: View {
    @EnvironmentObject private var container: AppContainer
    let content: @MainActor (AppContainer) -> Content

    init(@ViewBuilder content: @escaping @MainActor (AppContainer) -> Content) {
        self.content = content
    }

    var body: some View {
        content(container)
    }
}
