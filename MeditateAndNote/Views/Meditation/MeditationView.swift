//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
#warning("UI")
#warning("переход сразу на напоследнею медитацию если через переход на кнопку m")
#warning("додати звук до стейтів медитації")
struct MeditationView: View {
    @StateObject var viewModel: MeditationViewModel
    @EnvironmentObject var router: Router
    
    var body: some View {
        VStack {
            navigationBar
            meditationPlan
            Spacer()
            meditationCircle
            Spacer()
            progress
        }
        .overlay(
            Group {
                if viewModel.showTimeMeditation {
                    VStack(spacing: 0) {
                        Spacer()
                        TimeMeditationSheet(onSelection: { duration in
                            viewModel.showTimeMeditation = false
                            viewModel.start(with: duration)
                        })
                        .transition(.move(edge: .bottom))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .padding(0)
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
            HStack {
                Spacer()
                Button(action: {
                    router.navigationStackPath = []
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
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
                    .foregroundColor(.primary)
            }
        }
    }
    
    var meditationCircle: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: 250, height: 250)
            
            // Concentric rings animation
            ForEach(0..<5, id: \.self) { index in
                ConcentricRing(
                    index: index,
                    currentPhase: viewModel.currentPhase,
                    phaseProgress: viewModel.phaseProgress,
                    breathingColor: breathingColor
                )
            }
            
            // Center circle
            Circle()
                .fill(breathingColor.opacity(0.8))
                .frame(width: 80, height: 80)
                .animation(.easeInOut(duration: 0.3), value: breathingColor)
            
            // Center text
            VStack(spacing: 4) {
                if let currentPhase = viewModel.currentPhase {
                    Text(formatTime(currentPhase.duration - (currentPhase.duration * viewModel.phaseProgress)))
                        .font(.system(size: 24))
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    var progress: some View {
        Button(action: {
            switch viewModel.meditationState {
            case .notStarted:
                router.navigate(to: .sheet(.timeMeditation { duration in
                    viewModel.start(with: duration)
                }))
            case .started:
                viewModel.pause()
            case .paused:
                viewModel.resume()
            case .finished:
                break
                //TODO:
                ///router to reeding
            }
        }) {
            ZStack {
                MeditationProgressView(progress: viewModel.progress, color: .blue)
                Text(viewModel.meditationState.progressText)
                    .font(.system(size: 24))
                    .bold()
                    .foregroundColor(.black)
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
        MeditationView(viewModel: MeditationViewModel(meditation: SampleMeditationService().getMeditations().first!))
            .environmentObject(Router.previewRouter())
    }
}
