//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
import UIKit

struct MeditationView: View {
    @State var viewModel: MeditationViewModel
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @State private var showTimeSelection = true

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let breathe = breathSize(for: geometry.size.height)
            let progressWidth = progressBarWidth(for: geometry.size)
            VStack {
                navigationBar(isLandscape: isLandscape)
                meditationPlan
                Spacer()
                if !showTimeSelection {
                    breathingAnimation(size: breathe)
                }
                Spacer()
                progress(width: progressWidth)
            }
        }
        .background(themeManager.current.mainBackground.ignoresSafeArea())
        .overlay(
            Group {
                if showTimeSelection {
                    VStack(spacing: 0) {
                        Spacer()
                        TimeMeditationSheet(onSelection: { duration in
                            showTimeSelection = false
                            viewModel.start(with: duration, countdown: 3)
                        })
                        .transition(.move(edge: .bottom))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .padding(0)
                }
            }
        )
        .overlay(
            Group {
                if let countdown = viewModel.countdownRemaining {
                    Text("\(countdown)")
                        .font(.system(size: 120, weight: .light))
                        .foregroundColor(breathingColor.opacity(0.35))
                        .transition(.scale.combined(with: .opacity))
                        .id(countdown)
                }
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if viewModel.meditationState == .started {
                viewModel.pause()
            }
        }
    }
}

//MARK: - Extension
private extension MeditationView {
    func navigationBar(isLandscape: Bool) -> some View {
        ZStack {
            Text("\(viewModel.meditationTitle)")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.current.textPrimary)
            HStack {
                Spacer()
                Button(action: {
                    router.navigationStackPath = []
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.current.iconPrimary)
                        .frame(width: 32, height: 32)
                        .background(themeManager.current.toolbarBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
        }
        .padding(.horizontal, isLandscape ? 32 : 16)
    }
    
    var meditationPlan: some View {
        VStack(spacing: 8) {
            if let currentPhase = viewModel.currentPhase {
                Text(currentPhase.type.displayName)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.textPrimary)
            }
        }
    }
    
    @ViewBuilder
    func breathingAnimation(size: CGFloat) -> some View {
        switch AnimationSettings.shared.style {
        case .rings:
            meditationCircle(size: size)
        case .path:
            BreathingPathView(
                phases: viewModel.breathingPhases,
                phaseIndex: viewModel.currentPhaseIndex,
                phaseProgress: viewModel.phaseProgress,
                lineColor: themeManager.current.textPrimary,
                ballColor: breathingColor,
                height: size
            )
        }
    }

    func meditationCircle(size: CGFloat) -> some View {
        Circle()
            .stroke(themeManager.current.dividerColor, lineWidth: 2)
            .frame(width: size, height: size)
            .overlay(
                ForEach(0..<5, id: \.self) { index in
                    ConcentricRing(
                        index: index,
                        currentPhase: viewModel.currentPhase,
                        phaseProgress: viewModel.phaseProgress,
                        breathingColor: breathingColor
                    )
                }
            )
            .overlay(
                Circle()
                    .fill(breathingColor.opacity(0.8))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .animation(.easeInOut(duration: 0.3), value: breathingColor)
            )
            .overlay(
                VStack(spacing: 4) {
                    if let currentPhase = viewModel.currentPhase {
                        Text(formatTime(currentPhase.duration - (currentPhase.duration * viewModel.phaseProgress)))
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.current.textPrimary)
                    }
                }
            )
    }
    
    func progress(width: CGFloat) -> some View {
        Button(action: {
            switch viewModel.meditationState {
            case .notStarted:
                showTimeSelection = true
            case .started:
                viewModel.pause()
            case .paused:
                viewModel.resume()
            case .finished:
                if let duration = viewModel.completedDuration {
                    router.navigate(to: .push(.meditationCompletion(
                        meditation: viewModel.meditation,
                        duration: duration
                    )))
                }
            }
        }) {
            ZStack {
                MeditationProgressView(progress: viewModel.progress, color: breathingColor.opacity(0.8), width: width)
                Text(viewModel.meditationState.progressText)
                    .font(.system(size: 24))
                    .bold()
                    .foregroundColor(themeManager.current.textPrimary)
            }
        }
    }

    private func breathSize(for totalHeight: CGFloat) -> CGFloat {
        min(max(totalHeight * 0.55, 120), 250)
    }

    private func progressBarWidth(for size: CGSize) -> CGFloat {
        size.width > size.height ? 480 : 326
    }
    
    private var breathingColor: Color {
        guard let currentPhase = viewModel.currentPhase else { return themeManager.current.accentColor }
        return themeManager.current.breathingPhaseColor(currentPhase.type)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        return String(format: "%d", Int(max(time, 0)))
    }
}

// Display-only strings that describe domain states live in the presentation
// layer, so the Models keep pure identifiers.

extension MeditationState {
    var progressText: String {
        switch self {
        case .notStarted: return "Start"
        case .started: return "Tap to Pause"
        case .paused: return "Resume"
        case .finished: return "Done"
        }
    }
}

extension BreathingPhaseType {
    var displayName: String {
        switch self {
        case .inhale: return "Inhale"
        case .holdAfterInhale: return "Hold"
        case .exhale: return "Exhale"
        case .holdAfterExhale: return "Hold After Exhale"
        }
    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        let meditation = SampleMeditationService().getMeditations().first
            ?? Meditation(id: "preview", title: MeditationTitle("Preview"), breathingStyle: .fourSevenEight)
        return MeditationView(viewModel: MeditationViewModel(meditation: meditation))
            .environment(Router.previewRouter())
            .environment(ThemeManager())
    }
}
