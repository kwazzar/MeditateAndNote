//
//  NavigationContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 17.07.2025.
//

import SwiftUI

#warning("можливість керувати транзицією")
struct NavigationContainer<Content: View>: View {
    @State private var router: Router
    @ViewBuilder var content: () -> Content

    init(
        parentRouter: Router,
        tab: TabDestination? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _router = State(initialValue: parentRouter.childRouter(for: tab))
        self.content = content
    }

    var body: some View {
        return InnerContainer(router: router) {
            content()
        }
        .environment(router)
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

//MARK: - InnerContainer
private struct InnerContainer<Content: View>: View {
    let router: Router
    @ViewBuilder var content: () -> Content

    var body: some View {
        @Bindable var router = router
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
        .onChange(of: router.navigationStackPath) { _, _ in
            router.parent?.isDetailPresented = !router.navigationStackPath.isEmpty
        }
    }

    @ViewBuilder
    func navigationView(for destination: SheetDestination, from router: Router) -> some View {
        view(for: destination)
            .environment(router)
    }
    
    @ViewBuilder
    func navigationView(for destination: FullScreenDestination, from router: Router) -> some View {
        view(for: destination)
            .environment(router)
    }
}

struct NavigationContainer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationContainer(parentRouter: .previewRouter()) {
            Text("Hello")
        }
    }
}
