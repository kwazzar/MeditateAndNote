//
//  MeditateSelectView.swift
//  MeditateAndNote
//
//  Created by Quasar on 06.03.2025.
//

import SwiftUI

struct MeditateSelectView: View {
    @StateObject var viewModel: MeditateSelectViewModel
    @EnvironmentObject var router: Router
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Meditation Session")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Welcome to your meditation session")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Start Meditation") {
                //додати логіку запуску медитації                
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            
            Button("Close") {
                router.presentingSheet = nil
            }
            .font(.headline)
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green.opacity(0.1))
    }
}

struct MeditateSelectView_Previews: PreviewProvider {
    static var previews: some View {
        MeditateSelectView(viewModel: MeditateSelectViewModel())
            .environmentObject(Router.previewRouter())
    }
}
