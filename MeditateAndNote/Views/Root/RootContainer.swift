//
//  RootContainer.swift
//  MeditateAndNote
//
//  Created by Quasar on 23.11.2025.
//

import SwiftUI

struct RootContainer: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var container: AppContainer
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StreakTracker.self) private var streakTracker
    @Environment(\.scenePhase) private var scenePhase

    /// Launch-time gating: onboarding runs before the tab bar is mounted
    /// (see `OnboardingCoordinator` for the Router transition on completion).
    private enum StartupFlow {
        case undecided
        case onboarding
        case tabs
    }

    @State private var startupFlow: StartupFlow = .undecided
    @State private var onboardingViewModel: OnboardingViewModel?

    private var bindingSelectedTab: Binding<TabDestination> {
        Binding(
            get: { router.selectedTab ?? .home },
            set: { router.selectedTab = $0 }
        )
    }
    
    var body: some View {
        Group {
            switch startupFlow {
            case .undecided:
                Color.clear
                    .onAppear(perform: decideStartupFlow)
            case .onboarding:
                if let onboardingViewModel {
                    OnboardingView(viewModel: onboardingViewModel)
                        .environment(themeManager)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            case .tabs:
                mainTabBar
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: startupFlow)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { @MainActor in
                await streakTracker.refreshStreakState()
            }
        }
    }

    /// Decides once whether to show onboarding or jump straight to the tabs.
    private func decideStartupFlow() {
        guard startupFlow == .undecided else { return }
        let coordinator = OnboardingCoordinator(store: container.onboardingStore)

        // Dev tool: the `-showOnboarding` launch argument reopens onboarding
        // even after it was completed, without touching the persisted flag.
        // Usage: `xcrun simctl launch <SIM> nazar.MeditateAndNote -showOnboarding`
        let showsOnboardingOnDemand = ProcessInfo.processInfo.arguments.contains("-showOnboarding")

        guard coordinator.shouldShowOnboarding || showsOnboardingOnDemand else {
            startupFlow = .tabs
            return
        }

        onboardingViewModel = container.makeOnboardingViewModel {
            coordinator.onOnboardingCompleted(router: router)
            startupFlow = .tabs
        }
        startupFlow = .onboarding
    }
}

extension RootContainer {
    private var mainTabBar: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: bindingSelectedTab) {
                NavigationContainer(parentRouter: router, tab: .home) {
                    MainView(viewModel: container.makeMainViewModel())
                        .environment(themeManager)
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag(TabDestination.home)
                
                NavigationContainer(parentRouter: router, tab: .notes) {
                    NoteMenu(viewModel: container.makeNoteMenuViewModel())
                        .environment(themeManager)
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag(TabDestination.notes)
                
                NavigationContainer(parentRouter: router, tab: .meditations) {
                    MeditateSelectView(viewModel: container.makeMeditateSelectViewModel())
                        .environment(themeManager)
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag(TabDestination.meditations)
            }
            .ignoresSafeArea()
            
            CustomTabBar(selectedTab: bindingSelectedTab)
                .padding(.horizontal, 16)
                .offset(y: router.isDetailPresented ? 100 : 0)
                .animation(.snappy(duration: 0.25), value: router.isDetailPresented)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct RootContainer_Previews: PreviewProvider {
    static var previews: some View {
        RootContainer()
            .environmentObject(Router.previewRouter())
            .environmentObject(AppContainer())
            .environment(ThemeManager())
            .environment(StreakTracker())
    }
}
