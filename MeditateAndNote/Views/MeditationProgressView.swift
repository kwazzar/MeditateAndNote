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
        self.progress = progress
        self.color = color
        self.width = width
        self.height = height
    }

    var body: some View {
        ZStack {
            HStack {
                RoundedRectangle(cornerRadius: 100)
                    .fill(color)
                    .frame(width: CGFloat(progress) * width, height: height)
                    .animation(.linear(duration: 0.3), value: progress)
                    .shadow(color: color, radius: 5)
                    .overlay(
                        GeometryReader { geometry in
                            if progress >= 0.2 {
//                                Text("\(Int(progress * 100))%")
//                                    .font(.appFont(size: 18))
//                                    .foregroundColor(.black)
//                                    .frame(width: geometry.size.width,
//                                           height: height,
//                                           alignment: .center)
                            }
                        }
                    )
                Spacer()
            }
        }
        .frame(width: width, height: height)
    }
}
