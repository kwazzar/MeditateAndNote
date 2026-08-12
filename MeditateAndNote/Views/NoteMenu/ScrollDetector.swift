//
//  ScrollDetector.swift
//  MeditateAndNote
//
//  Created by kwazzar on 12.08.2026.
//

import SwiftUI

// MARK: - Обёртка над UIScrollView для отслеживания состояния скролла

struct ScrollDetector<Content: View>: UIViewRepresentable {
    @Binding var isScrolling: Bool
    let content: Content
    
    init(isScrolling: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isScrolling = isScrolling
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.contentInsetAdjustmentBehavior = .never
        
        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        context.coordinator.hostingController = hosting
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isScrolling: $isScrolling)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var isScrolling: Bool
        var hostingController: UIHostingController<Content>?
        private var hideWorkItem: DispatchWorkItem?
        
        init(isScrolling: Binding<Bool>) {
            self._isScrolling = isScrolling
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            hideWorkItem?.cancel()
            
            if !isScrolling {
                isScrolling = true
            }
            
            let workItem = DispatchWorkItem { [weak self] in
                self?.isScrolling = false
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
        }
    }
}
