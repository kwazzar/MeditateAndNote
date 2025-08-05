//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
#warning("sheet for pick time meditation")

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
        Text("\(viewModel.meditation.title)")
    }

    var meditationPlan: some View {
        Text("meditationPlan")
    }

    var meditationCircle: some View {
        Text("meditationCircle")
    }

    var progressBar: some View {
      return MeditationProgressView(progress: viewModel.progress, color: .blue)

    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationView(viewModel: MeditationViewModel(meditation: SampleMeditationService().getMeditations().first!))
    }
}
