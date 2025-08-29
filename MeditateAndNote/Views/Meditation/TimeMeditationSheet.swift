//
//  TimeMeditationSheet.swift
//  MeditateAndNote
//
//  Created by Quasar on 05.08.2025.
//

import SwiftUI

struct TimeMeditationSheet: View {
    @EnvironmentObject var router: Router
    @State private var selectedDuration: MeditationDuration = .threeMin
    let onSelection: (MeditationDuration) -> Void

    var body: some View {
        VStack(spacing: 5) {
            Spacer().frame(height: 20)

            Picker("Duration", selection: $selectedDuration) {
                ForEach(MeditationDuration.allCases) { duration in
                    Text(duration.englishLabel)
                        .tag(duration)
                }
            }
            .pickerStyle(WheelPickerStyle())

            .clipShape(
                Rectangle()
                    .path(in: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 150))
            )
            .mask(
                GeometryReader { geometry in
                    CustomTopRoundedShape()
                        .offset(y: -20)
                }
            )

            Text("Select Duration")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 25)

            Button(action: {
                onSelection(selectedDuration)
            }) {
                Text("Start Meditation")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding(.bottom)
        .background(
            CustomTopRoundedShape()
                .fill(Color(.systemBackground))
        )
        .clipShape(CustomTopRoundedShape())
        .shadow(radius: 10)
    }
}

// MARK: - Custom Shape
fileprivate struct CustomTopRoundedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: 140)) // left
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 140),
                          control: CGPoint(x: rect.width / 2, y: -10)) // up
        path.addLine(to: CGPoint(x: rect.width, y: rect.height)) // right
        path.closeSubpath()
        return path
    }
}

// MARK: - Extension for English Labels
extension MeditationDuration {
    var englishLabel: String {
        switch self {
        case .oneMin:
            return "1 minute"
        case .threeMin:
            return "3 minutes"
        case .fiveMin:
            return "5 minutes"
        }
    }
}
