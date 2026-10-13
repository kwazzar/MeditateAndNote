//
//  SubscriptionSection.swift
//  MeditateAndNote
//

import SwiftUI

struct SubscriptionSection: View {
    let container: AppContainer

    @Environment(ThemeManager.self) private var themeManager
    @State private var showsPaywall = false

    private var viewModel: SubscriptionViewModel {
        container.makeSubscriptionViewModel()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isPremium ? "checkmark.seal.fill" : "crown.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.current.streakActiveMeditation)
                Text(viewModel.isPremium ? "Pro Active" : "Upgrade to Pro")
                    .font(.headline)
                    .foregroundColor(themeManager.current.textPrimary)
            }

            if !viewModel.isPremium {
                Button {
                    showsPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock all features")
                                .font(.body)
                                .foregroundColor(themeManager.current.textPrimary)
                            Text(viewModel.priceText ?? "One-time and auto-renewing subscriptions")
                                .font(.caption)
                                .foregroundColor(themeManager.current.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.current.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            } else if let price = viewModel.priceText {
                Text("\(price) — auto-renews. Manage anytime in Settings.")
                    .font(.caption)
                    .foregroundColor(themeManager.current.textSecondary)
            }
        }
        .padding(20)
        .background(themeManager.current.editorBackground)
        .cornerRadius(16)
        .fullScreenCover(isPresented: $showsPaywall) {
            PaywallView(container: container)
                .environment(themeManager)
        }
    }
}