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
        print("🏗️ NavigationContainer init called")
        _router = StateObject(wrappedValue: parentRouter.childRouter(for: tab))
        self.content = content
    }

    var body: some View {
        print("🏗️ NavigationContainer body called")
        return InnerContainer(router: router) {
            content()
        }
        .environmentObject(router)
        .onAppear {
            print("🏗️ NavigationContainer onAppear - setting router active")
            router.setActive()
            print("🏗️ Router is now active: \(router.isActive)")
        }
        .onDisappear {
            print("🏗️ NavigationContainer onDisappear")
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
        print("🏢 InnerContainer body called")
        print("🏢 navigationStackPath: \(router.navigationStackPath)")
        print("🏢 presentingSheet: \(String(describing: router.presentingSheet))")
        print("🏢 presentingFullScreen: \(String(describing: router.presentingFullScreen))")

        return NavigationStack(path: $router.navigationStackPath) {
            content()
                .navigationDestination(for: PushDestination.self) { destination in
                    return view(for: destination)
                        .onAppear {
                            print("🏢 NavigationDestination called for: \(destination)")
                        }
                }
        }
        .sheet(item: $router.presentingSheet) { sheet in
            navigationView(for: sheet, from: router)
                .onAppear {
                    print("🏢 Sheet appeared: \(sheet)")
                }
        }
        .fullScreenCover(item: $router.presentingFullScreen) { fullScreen in
            navigationView(for: fullScreen, from: router)
                .onAppear {
                    print("🏢 FullScreenCover appeared: \(fullScreen)")
                }
        }
        .onReceive(router.$presentingSheet) { sheet in
            print("🔄 Router presentingSheet changed to: \(String(describing: sheet))")
        }
        .onReceive(router.$presentingFullScreen) { fullScreen in
            print("🔄 Router presentingFullScreen changed to: \(fullScreen)")
        }
    }

    @ViewBuilder
    func navigationView(for destination: SheetDestination, from router: Router) -> some View {
        view(for: destination)
            .environmentObject(router)
            .onAppear {
                print("🔧 Creating navigationView for SheetDestination: \(destination)")

            }
    }

    @ViewBuilder
    func navigationView(for destination: FullScreenDestination, from router: Router) -> some View {
        view(for: destination)
            .environmentObject(router)
            .onAppear {
                print("🔧 Creating navigationView for FullScreenDestination: \(destination)")

            }
    }
}

struct NavigationContainer_Previews: PreviewProvider {
    static var previews: some View {
            NavigationContainer(parentRouter: .previewRouter()) {
                Text("Hello")
            }
    }
}
