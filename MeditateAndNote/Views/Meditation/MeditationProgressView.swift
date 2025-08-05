//
//  MeditationProgressView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

struct MeditationProgressView: View {
    let progress: Float
    let color: Color
    let width: CGFloat
    let height: CGFloat

    init(progress: Float,
         color: Color,
         width: CGFloat = 326,
         height: CGFloat = 44) {
        self.progress = max(0, min(progress, 1))
        self.color = color
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background capsule
            Capsule()
                .fill(Color.gray.opacity(0.2))

            // Foreground fill
            GeometryReader { geometry in
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())
    }
}
