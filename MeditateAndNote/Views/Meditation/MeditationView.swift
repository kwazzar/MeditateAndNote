//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
#warning("meditate and note Flow")
#warning("вигляд time навігейшн sheet це меню вибору книги")
struct MeditationView: View {
    @State var viewModel: MeditationViewModel
    @EnvironmentObject var router: Router
    @Environment(ThemeManager.self) private var themeManager
    @State private var showTimeSelection = true
    @State private var animationStyle: BreathingAnimationStyle = .path

    var body: some View {
        ZStack {
            themeManager.current.mainBackground.ignoresSafeArea()

            VStack {
                navigationBar
                meditationPlan
                Spacer()
                breathingAnimation
                Spacer()
                progress
            }
        }
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
    }
}

//MARK: - Extension
private extension MeditationView {
    var navigationBar: some View {
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
        .padding(.horizontal)
    }
    
    var meditationPlan: some View {
        VStack(spacing: 8) {
            if let currentPhase = viewModel.currentPhase {
                Text(currentPhase.type.rawValue)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.current.textPrimary)
            }
        }
    }
    
    @ViewBuilder
    var breathingAnimation: some View {
        switch animationStyle {
        case .rings:
            meditationCircle
        case .path:
            BreathingPathView(
                phases: viewModel.breathingPhases,
                phaseIndex: viewModel.currentPhaseIndex,
                phaseProgress: viewModel.phaseProgress,
                lineColor: themeManager.current.textPrimary,
                ballColor: breathingColor
            )
        }
    }

    var meditationCircle: some View {
        Circle()
            .stroke(themeManager.current.dividerColor, lineWidth: 2)
            .frame(width: 250, height: 250)
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
                    .frame(width: 80, height: 80)
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
    
    var progress: some View {
        Button(action: {
            switch viewModel.meditationState {
            case .notStarted:
                showTimeSelection = true
            case .started:
                viewModel.pause()
            case .paused:
                viewModel.resume()
            case .finished:
                router.navigate(to: .push(.readingView))
            }
        }) {
            ZStack {
                MeditationProgressView(progress: viewModel.progress, color: breathingColor.opacity(0.8))
                Text(viewModel.meditationState.progressText)
                    .font(.system(size: 24))
                    .bold()
                    .foregroundColor(themeManager.current.textPrimary)
            }
        }
    }
    
    private var breathingColor: Color {
        guard let currentPhase = viewModel.currentPhase else { return .blue }
        
        switch currentPhase.type {
        case .inhale:
            return .cyan
        case .holdAfterInhale:
            return .blue
        case .exhale:
            return .purple
        case .holdAfterExhale:
            return .indigo
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        return String(format: "%d", Int(max(time, 0)))
    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        let meditation = SampleMeditationService().getMeditations().first
            ?? Meditation(id: "preview", title: MeditationTitle("Preview"), breathingStyle: .fourSevenEight)
        return MeditationView(viewModel: MeditationViewModel(meditation: meditation))
            .environmentObject(Router.previewRouter())
            .environment(ThemeManager())
    }
}
