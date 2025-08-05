//
//  MeditationViewModel.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

final class MeditationViewModel: ObservableObject {
    let meditation: Meditation
    @Published var meditationTime: TimeInterval = 0
    private var totalDuration: TimeInterval = 0
    private var timer: Timer?

    var progress: Float {
        guard totalDuration > 0 else { return 0 }
        return Float((totalDuration - meditationTime) / totalDuration)
    }

    init(meditation: Meditation) {
        self.meditation = meditation
    }

    func start(with duration: MeditationDuration) {
        totalDuration = duration.rawValue
        meditationTime = duration.rawValue

        timer?.invalidate()

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
