//
//  MeditateSelectView.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import SwiftUI

struct MeditateSelectView: View {
    @State var viewModel: MeditateSelectViewModel
    @EnvironmentObject var router: Router
    @Environment(ThemeManager.self) private var themeManager
    @State private var showSoundSettings = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if viewModel.meditations.isEmpty {
                    emptyStateView
                } else {
                    meditationGridSection
                }
                actionButtonsSection
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(themeManager.current.mainBackground)
        .sheet(item: $viewModel.infoItem) { item in
            MeditationInfoSheet(item.meditation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSoundSettings) {
            SoundSettingsSheet(soundSettings: SoundSettings.shared)
        }
        .onAppear {
            viewModel.loadMeditations()
        }
    }
}

//MARK: - Extension
private extension MeditateSelectView {
    private var headerSection: some View {
        ZStack {
            VStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.current.streakActiveMeditation)

                Text(viewModel.selectedMeditation?.title.rawValue ?? "Meditation Session")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.current.textPrimary)

                Text(viewModel.selectedMeditation != nil ?
                     "Ready to begin your journey" :
                        "Choose your path to inner peace")
                .font(.body)
                .foregroundColor(themeManager.current.textSecondary)
                .multilineTextAlignment(.center)
            }
            //            VStack {
            //                HStack {
            //                    Spacer()
            //
            //                    Button {
            //                        router.presentingSheet = nil
            //                        router.presentingFullScreen = nil
            //                        router.navigationStackPath = []
            //                    } label: {
            //                        Image(systemName: "xmark")
            //                            .font(.system(size: 16, weight: .medium))
            //                            .foregroundColor(.secondary)
            //                            .padding(8)
            //                            .background(
            //                                Circle()
            //                                    .fill(Color.gray.opacity(0.1))
            //                            )
            //                    }
            //                    .buttonStyle(PlainButtonStyle())
            //                }
            //
            //                Spacer()
            //            }
        }
    }

    private var meditationGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Meditations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.current.textPrimary)
                    .padding(.horizontal, 4)

                Spacer()

                Text("Long press for details")
                    .font(.caption)
                    .foregroundColor(themeManager.current.textSecondary)
                    .italic()

                Button {
                    showSoundSettings = true
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.current.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(themeManager.current.toolbarBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.meditations) { meditation in
                    MeditationCard(
                        meditation: meditation,
                        isSelected: viewModel.selectedMeditation?.id == meditation.id,
                        onSelect: {
                            viewModel.selectMeditation(meditation)
                        },
                        onLongPress: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()

                            // Показуємо інформаційний лист
                            viewModel.infoItem = MeditationInfoItem(meditation: meditation)
                        }
                    )
                }
            }
        }
    }

    private var selectedMeditationSection: some View {
        Group {
            if let selectedMeditation = viewModel.selectedMeditation {
                VStack(spacing: 12) {
                    Text("Selected Meditation")
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(themeManager.current.streakSuccess)

                        VStack(alignment: .leading) {
                            Text(selectedMeditation.title.rawValue)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.current.textPrimary)

                            Text("empty here")
                                .font(.caption)
                                .foregroundColor(themeManager.current.textSecondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(themeManager.current.streakSuccess.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("Start Meditation") {
                viewModel.startMeditation()

                if let selectedMeditation = viewModel.selectedMeditation {
                    viewModel.saveLastSelectedMeditation(selectedMeditation)
                    router.navigate(to: .push(.meditation(selectedMeditation)))
                }

                router.presentingSheet = nil
            }
            .font(.headline)
            .foregroundColor(themeManager.current.buttonText)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                viewModel.selectedMeditation != nil || !viewModel.meditations.isEmpty
                ? themeManager.current.accentButton
                : themeManager.current.dividerColor
            )
            .cornerRadius(12)
            .disabled(viewModel.meditations.isEmpty)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 60))
                .foregroundColor(themeManager.current.textSecondary)

            Text("No Meditations Available")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.textPrimary)

            Text("Check back later for guided meditation sessions")
                .font(.body)
                .foregroundColor(themeManager.current.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

struct MeditateSelectView_Previews: PreviewProvider {
    static var previews: some View {
        MeditateSelectView(viewModel: AppContainer().makeMeditateSelectViewModel())
            .environmentObject(Router.previewRouter())
    }
}
