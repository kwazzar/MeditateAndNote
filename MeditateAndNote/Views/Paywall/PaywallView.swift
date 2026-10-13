//
//  PaywallView.swift
//  MeditateAndNote
//

import SwiftUI
import MeditateAndNoteCore

struct PaywallView: View {
    let container: AppContainer

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makePaywallViewModel())
    }

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    private let benefits: [Benefit] = [
        .init(icon: "paintpalette.fill", text: "All premium themes"),
        .init(icon: "sparkles", text: "AI writing support"),
        .init(icon: "chart.line.uptrend.xyaxis", text: "Detailed progress insights"),
        .init(icon: "icloud.fill", text: "Unlimited note storage"),
    ]

    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()

            content(viewModel)
        }
        .onChange(of: viewModel.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
        .task {
            await viewModel.load()
        }
    }

    private func content(_ viewModel: PaywallViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundColor(themeManager.current.streakActiveMeditation)

                VStack(spacing: 8) {
                    Text("Meditate & Note Pro")
                        .font(.title2.bold())
                        .foregroundColor(themeManager.current.textPrimary)
                    Text("Unlock everything on your journey")
                        .font(.subheadline)
                        .foregroundColor(themeManager.current.textSecondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(benefits) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: benefit.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.current.streakActiveMeditation)
                                .frame(width: 28, height: 28)
                            Text(benefit.text)
                                .font(.body)
                                .foregroundColor(themeManager.current.textPrimary)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 8)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(themeManager.current.streakActiveMeditation)
                        .padding(.vertical, 12)
                }

                packageCards(viewModel)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await viewModel.purchaseSelected() }
                } label: {
                    Text(viewModel.selectedPackage.map { "Subscribe \($0.priceString)" } ?? "Subscribe")
                        .font(.headline)
                        .foregroundColor(themeManager.current.iconPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(themeManager.current.streakActiveMeditation)
                        .cornerRadius(14)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isLoading)

                Button("Restore Purchase") {
                    Task { await viewModel.restore() }
                }
                .font(.subheadline)
                .foregroundColor(themeManager.current.textSecondary)

                // Static legal links until App Store metadata is attached.
                Link("Terms", destination: URL(string: "https://www.revenuecat.com/terms/")!)
                Link("Privacy Policy", destination: URL(string: "https://www.revenuecat.com/privacy/")!)
                    .font(.caption)
                    .foregroundColor(themeManager.current.textSecondary)

                Button("Close") { dismiss() }
                    .font(.subheadline)
                    .foregroundColor(themeManager.current.textSecondary)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func packageCards(_ viewModel: PaywallViewModel) -> some View {
        ForEach(viewModel.packages) { package in
            Button {
                viewModel.selectedPackage = package
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedPackage?.id == package.id ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(themeManager.current.streakActiveMeditation)
                    Text(package.title)
                        .font(.body)
                        .foregroundColor(themeManager.current.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(package.priceString)
                        .font(.headline)
                        .foregroundColor(themeManager.current.textPrimary)
                }
                .padding(16)
                .background(themeManager.current.editorBackground)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}