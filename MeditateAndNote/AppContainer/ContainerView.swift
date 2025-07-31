//
//  ContainerView.swift
//  MeditateAndNote
//
//  Created by Quasar on 31.07.2025.
//

import SwiftUI

struct ContainerView<Content: View>: View {
    @EnvironmentObject private var container: AppContainer
    let content: (AppContainer) -> Content

    init(@ViewBuilder content: @escaping (AppContainer) -> Content) {
        self.content = content
    }

    var body: some View {
        content(container)
    }
}
