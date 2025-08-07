//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
#warning("UI")
#warning("переход сразу на напоследнею медитацию если через переход на кнопку m")
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
            MeditationProgressView(progress: viewModel.progress, color: .blue)
        }
        .onAppear {
            router.navigate(to: .sheet(.timeMeditation { duration in
                viewModel.start(with: duration)
            }))
        }
    }
}

//MARK: - Extension
private extension MeditationView {
    var navigationBar: some View {
        Text("\(viewModel.meditation.title)")
    }

    var meditationPlan: some View {
        VStack(spacing: 8) {
            if let currentPhase = viewModel.currentPhase {
                Text(currentPhase.type.rawValue)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

//                Text("Cycle \(viewModel.cycleCount + 1)")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
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
