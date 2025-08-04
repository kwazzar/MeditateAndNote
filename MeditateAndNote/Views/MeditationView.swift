//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI

struct MeditationView: View {
    @StateObject var viewModel: MeditationViewModel

    var body: some View {
        VStack {
            navigationBar
            meditationPlan
            Spacer()
            meditationCircle
            Spacer()
            progressBar

        }
    }
}

//MARK: - Extension
private extension MeditationView {
    var navigationBar: some View {
        Text("navigationBar")
    }

    var meditationPlan: some View {
        Text("meditationPlan")
    }

    var meditationCircle: some View {
        Text("meditationCircle")
    }

    var progressBar: some View {
        MeditationProgressView(progress: Float(viewModel.meditationTime), color: .blue)
    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationView(viewModel: MeditationViewModel())
    }
}
