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
    
    private var bindingSelectedTab: Binding<TabDestination> {
        Binding(
            get: { router.selectedTab ?? .home },
            set: { router.selectedTab = $0 }
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: bindingSelectedTab) {
                NavigationContainer(parentRouter: router, tab: .home) {
                    MainView(viewModel: container.makeMainViewModel())
                        .environment(themeManager)
                        .toolbar(.hidden, for: .tabBar)
                }
                .tag(TabDestination.home)
                
                NavigationContainer(parentRouter: router, tab: .notes) {
                    NoteMenu(viewModel: container.makeNoteMenuView())
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

struct CustomTabBar: View {
    @Binding var selectedTab: TabDestination
    
    var body: some View {
        HStack(spacing: 32) {
            tabButton(.notes, systemImage: "note.text", title: "Notes")
            tabButton(.home, systemImage: "house", title: "Home")
            tabButton(.meditations, systemImage: "leaf", title: "Meditations")
            // додаси інші, якщо будуть
        }
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
    }
    
    private func tabButton(_ tab: TabDestination,
                           systemImage: String,
                           title: String) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.12) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RootContainer_Previews: PreviewProvider {
    static var previews: some View {
        RootContainer()
            .environmentObject(Router.previewRouter())
            .environmentObject(AppContainer())
            .environment(ThemeManager())
    }
}
