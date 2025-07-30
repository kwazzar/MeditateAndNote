//
//  Router.swift
//  MeditateAndNote
//
//  Created by Quasar on 20.07.2025.
//

import Foundation
import OSLog

public final class Router: ObservableObject {
    let id = UUID()
    let level: Int

    /// Specifies which tab the router was build for
    public let identifierTab: TabDestination?

    /// Only relevant for the `level 0` root router. Defines the tab to select
    @Published public var selectedTab: TabDestination?

    /// Values presented in the navigation stack
    @Published public var navigationStackPath: [PushDestination] = []

    /// Current presented sheet
    @Published public var presentingSheet: SheetDestination?

    /// Current presented full screen
    @Published public var presentingFullScreen: FullScreenDestination?

    #warning("Logger")
    public let logger = Logger(subsystem: Config.bundleID, category: "Navigation")

    /// Reference to the parent router to form a hierarchy
    /// Router levels increase for the children
    weak var parent: Router?

    /// A way to track which router is visible/active
    /// Used for deep link resolution
    private(set) var isActive: Bool = false

    public init(level: Int, identifierTab: TabDestination?) {
        self.level = level
        self.identifierTab = identifierTab
        self.parent = nil

        logger.debug("\(self.debugDescription) initialized")
    }

    deinit {
        logger.debug("\(self.debugDescription) cleared")
    }

    private func resetContent() {
        navigationStackPath = []
        presentingSheet = nil
        presentingFullScreen = nil
    }
}

// MARK: - Router Management

public extension Router {
    func childRouter(for tab: TabDestination? = nil) -> Router {
        let router = Router(level: level + 1, identifierTab: tab ?? identifierTab)
        router.parent = self
        return router
    }

    func setActive() {
        logger.debug("\(self.debugDescription): \(#function)")
        parent?.resignActive()
        isActive = true
    }

    func resignActive() {
        logger.debug("\(self.debugDescription): \(#function)")
        isActive = false
        parent?.setActive()
    }

    static func previewRouter() -> Router {
        Router(level: 0, identifierTab: nil)
    }
}

// MARK: - Navigation
public extension Router {
    func navigate(to destination: Destination) {
        // КРИТИЧНО ВАЖЛИВО: Додайте цей print
        print("🚀🚀🚀 ROUTER NAVIGATE CALLED: \(destination)")
        print("🚀 Router level: \(level), isActive: \(isActive)")
        print("🚀 Router ID: \(shortId)")

        switch destination {
        case let .tab(tab):
            print("🚀 Calling select tab: \(tab)")
            select(tab: tab)

        case let .push(destination):
            print("🚀 Calling push: \(destination)")
            push(destination)

        case let .sheet(destination):
            print("🚀 Calling present sheet: \(destination)")
            present(sheet: destination)

        case let .fullScreen(destination):
            print("🚀 Calling present fullScreen: \(destination)")
            present(fullScreen: destination)
        }
    }

    func push(_ destination: PushDestination) {
        print("📱📱📱 PUSH METHOD CALLED: \(destination)")
        print("📱 Current navigationStackPath: \(navigationStackPath)")
        print("📱 Adding to path...")

        navigationStackPath.append(destination)

        print("📱 New navigationStackPath: \(navigationStackPath)")
        print("📱 navigationStackPath.count: \(navigationStackPath.count)")
    }

    func present(sheet destination: SheetDestination) {
        print("📋📋📋 PRESENT SHEET CALLED: \(destination)")
        print("📋 Current presentingSheet: \(String(describing: presentingSheet))")

        presentingSheet = destination

        print("📋 New presentingSheet: \(String(describing: presentingSheet))")
    }

    func present(fullScreen destination: FullScreenDestination) {
        print("📺📺📺 PRESENT FULLSCREEN CALLED: \(destination)")
        print("📺 Current presentingFullScreen: \(String(describing: presentingFullScreen))")

        presentingFullScreen = destination

        print("📺 New presentingFullScreen: \(String(describing: presentingFullScreen))")
    }

        func select(tab destination: TabDestination) {
            logger.debug("\(self.debugDescription) \(#function) \(destination.rawValue)")
            if level == 0 {
                selectedTab = destination
            } else {
                parent?.select(tab: destination)
                resetContent()
            }
        }

        func deepLinkOpen(to destination: Destination) {
            guard isActive else { return }
    
            logger.debug("\(self.debugDescription): \(#function) \(destination)")
            navigate(to: destination)
        }
}

//public extension Router {
//    func navigate(to destination: Destination) {
//        switch destination {
//        case let .tab(tab):
//            select(tab: tab)
//
//        case let .push(destination):
//            push(destination)
//
//        case let .sheet(destination):
//            present(sheet: destination)
//
//        case let .fullScreen(destination):
//            present(fullScreen: destination)
//        }
//    }
//
//    func select(tab destination: TabDestination) {
//        logger.debug("\(self.debugDescription) \(#function) \(destination.rawValue)")
//        if level == 0 {
//            selectedTab = destination
//        } else {
//            parent?.select(tab: destination)
//            resetContent()
//        }
//    }
//
//    func push(_ destination: PushDestination) {
//        logger.debug("\(self.debugDescription): \(#function) \(destination)")
//        navigationStackPath.append(destination)
//    }
//
//    func present(sheet destination: SheetDestination) {
//        logger.debug("\(self.debugDescription): \(#function) \(destination)")
//        logger.debug("Previous presentingSheet: \(String(describing: self.presentingSheet))")
//        presentingSheet = destination
//        logger.debug("New presentingSheet: \(String(describing: self.presentingSheet))")
//    }
//
//    func present(fullScreen destination: FullScreenDestination) {
//        logger.debug("\(self.debugDescription): \(#function) \(destination)")
//        logger.debug("Previous presentingFullScreen: \(String(describing: self.presentingFullScreen))")
//        presentingFullScreen = destination
//        logger.debug("New presentingFullScreen: \(String(describing: self.presentingFullScreen))")
//    }
//
//    func deepLinkOpen(to destination: Destination) {
//        guard isActive else { return }
//
//        logger.debug("\(self.debugDescription): \(#function) \(destination)")
//        navigate(to: destination)
//    }
//}

extension Router: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Router[\(shortId) - \(identifierTabName) - Level: \(level)]"
    }

    private var shortId: String { String(id.uuidString.split(separator: "-").first ?? "") }

    private var identifierTabName: String {
        identifierTab?.rawValue ?? "No Tab"
    }
}

