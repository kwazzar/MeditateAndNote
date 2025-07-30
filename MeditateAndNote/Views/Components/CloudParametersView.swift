//
//  CloudParametersView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct CloudParametersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Параметры")
                .font(.title2)
                .bold()

            HStack(spacing: 20) {
                ParameterItem(title: "Параметр 1", value: "85%")
                ParameterItem(title: "Параметр 2", value: "64%")
                ParameterItem(title: "Параметр 3", value: "92%")
            }
            .padding()
            .background(.red)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .padding()
    }
}

struct ParameterItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .bold()
        }
    }
}
