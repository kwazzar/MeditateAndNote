//
//  MeditateSelectView.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import SwiftUI
#warning("спробувати вставити в місцеву логіку навігації")

struct MeditateSelectView: View {
    @StateObject var viewModel: MeditateSelectViewModel
    @EnvironmentObject var router: Router

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
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
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(item: $viewModel.selectedMeditationForInfo) { meditation in
            MeditationInfoSheet(meditation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    .foregroundColor(.green)

                Text(viewModel.selectedMeditation?.title ?? "Meditation Session")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(viewModel.selectedMeditation != nil ?
                     "Ready to begin your journey" :
                        "Choose your path to inner peace")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        router.presentingSheet = nil
                        router.presentingFullScreen = nil
                        router.navigationStackPath = []
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
        }
    }

    private var meditationGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Meditations")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)

                Spacer()

                // Підказка для користувача
                Text("Long press for details")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
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
                                viewModel.selectedMeditationForInfo = meditation
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
                            .foregroundColor(.green)

                        VStack(alignment: .leading) {
                            Text(selectedMeditation.title)
                                .font(.body)
                                .fontWeight(.medium)

                            Text("empty here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
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
                    router.navigate(to: .push(.meditation(id: selectedMeditation.id)))
                }

                router.presentingSheet = nil
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                viewModel.selectedMeditation != nil || !viewModel.meditations.isEmpty
                ? Color.blue
                : Color.gray
            )
            .cornerRadius(12)
            .disabled(viewModel.meditations.isEmpty)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Meditations Available")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Check back later for guided meditation sessions")
                .font(.body)
                .foregroundColor(.secondary)
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
