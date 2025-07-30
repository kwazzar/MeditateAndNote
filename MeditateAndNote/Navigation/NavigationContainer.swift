//
//  NavigationContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 17.07.2025.
//

import SwiftUI

struct NavigationContainer<Content: View>: View {
    @StateObject var router: Router
    @ViewBuilder var content: () -> Content

    init(
        parentRouter: Router,
        tab: TabDestination? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _router = StateObject(wrappedValue: parentRouter.childRouter(for: tab))
        self.content = content
    }

    var body: some View {
        return InnerContainer(router: router) {
            content()
        }
        .environmentObject(router)
        .onAppear {
            router.setActive()
        }
        .onDisappear {
            router.resignActive()
        }
        .onOpenURL(perform: openDeepLinkIfFound(for:))
    }

    func openDeepLinkIfFound(for url: URL) {
        if let destination = DeepLink.destination(from: url) {
            router.deepLinkOpen(to: destination)
        } else {
            router.logger.warning("No destination matches \(url)")
        }
    }
}

private struct InnerContainer<Content: View>: View {
    @ObservedObject var router: Router
    @ViewBuilder var content: () -> Content

    var body: some View {
        return NavigationStack(path: $router.navigationStackPath) {
            content()
                .navigationDestination(for: PushDestination.self) { destination in
                    return view(for: destination)
                }
        }
        .sheet(item: $router.presentingSheet) { sheet in
            navigationView(for: sheet, from: router)
        }
        .fullScreenCover(item: $router.presentingFullScreen) { fullScreen in
            navigationView(for: fullScreen, from: router)
        }
    }

    @ViewBuilder
    func navigationView(for destination: SheetDestination, from router: Router) -> some View {
        view(for: destination)
            .environmentObject(router)
    }
    
    @ViewBuilder
    func navigationView(for destination: FullScreenDestination, from router: Router) -> some View {
        view(for: destination)
            .environmentObject(router)
    }
}

struct NavigationContainer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationContainer(parentRouter: .previewRouter()) {
            Text("Hello")
        }
    }
}
