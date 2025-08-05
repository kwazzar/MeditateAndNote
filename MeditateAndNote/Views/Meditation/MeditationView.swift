//
//  MeditationView.swift
//  MeditateAndNote
//
//  Created by Quasar on 04.08.2025.
//

import SwiftUI
#warning("UI")
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
        Text("meditationPlan")
    }

    var meditationCircle: some View {
        Text("meditationCircle")
    }
}

struct MeditationView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationView(viewModel: MeditationViewModel(meditation: SampleMeditationService().getMeditations().first!))
    }
}
