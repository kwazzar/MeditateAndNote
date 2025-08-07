//
//  TimeMeditationSheet.swift
//  MeditateAndNote
//
//  Created by Quasar on 05.08.2025.
//

import SwiftUI
#warning("UI")
#warning("добавить маску для верха шита")
struct TimeMeditationSheet: View {
    @EnvironmentObject var router: Router
    @State private var selectedDuration: MeditationDuration = .threeMin
    let onSelection: (MeditationDuration) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Select Duration")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 25)

            Picker("Duration", selection: $selectedDuration) {
                ForEach(MeditationDuration.allCases) { duration in
                    Text(duration.englishLabel)
                        .tag(duration)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 150)

            Spacer().frame(height:40)

            Button(action: {
                onSelection(selectedDuration)
                router.presentingSheet = nil

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
        .padding()
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
