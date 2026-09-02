//
//  OnboardingView.swift
//  MeditateAndNote
//
//  Created by Quasar on 02.09.2026.
//

import SwiftUI

/// Paging container for the onboarding flow: swipe between slides with a
/// page-dots indicator, "Skip" button on every slide and a
/// "Next" / "Start" footer button. All state lives in `OnboardingViewModel`.
struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 24) {
            skipButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .padding(.top, 12)

            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageIndicator
            footerButton
                .padding(.bottom, 40)
        }
        .background(themeManager.current.mainBackground)
    }

    // MARK: - Header

    private var skipButton: some View {
        Button("Skip") {
            viewModel.skip()
        }
        .font(.subheadline)
        .foregroundStyle(themeManager.current.textSecondary)
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalPages, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentPage
                          ? themeManager.current.iconPrimary
                          : themeManager.current.dividerColor)
                    .frame(width: index == viewModel.currentPage ? 10 : 8,
                           height: index == viewModel.currentPage ? 10 : 8)
            }
        }
    }

    // MARK: - Footer

    private var footerButton: some View {
        Button {
            if viewModel.isOnLastPage {
                viewModel.start()
            } else {
                viewModel.goToNextPage()
            }
        } label: {
            Text(viewModel.isOnLastPage ? "Start" : "Next")
                .font(.headline)
                .foregroundStyle(themeManager.current.buttonText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(themeManager.current.accentButton)
                )
                .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let store = UserDefaultsOnboardingStore(
            defaults: UserDefaults(suiteName: "preview_onboarding")!
        )
        OnboardingView(viewModel: OnboardingViewModel(
            store: store,
            pages: OnboardingPage.appSlides,
            onCompletion: {}
        ))
        .environment(ThemeManager())
    }
}