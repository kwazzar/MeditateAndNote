//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

final class MeditationViewModel: ObservableObject {
    let meditation: Meditation
    @Published var meditationTime: TimeInterval
    private var timer: Timer?
    var progress: Float {
        guard meditation.duration > 0 else { return 0 }
        return Float((meditation.duration - meditationTime) / meditation.duration)
    }

    init(meditation: Meditation) {
        self.meditation = meditation
        self.meditationTime = meditation.duration

        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.meditationTime > 0 {
                withAnimation(.linear(duration: 0.3)) {
                    self.meditationTime -= 1
                }
            } else {
                self.timer?.invalidate()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
