//
//  MainTheme.swift
//  MeditateAndNote
//
//  Created by kwazzar on 22.07.2026.
//

import SwiftUI

enum MainTheme: String {
    case liquidGlass, breathing, softDawn, darkZen
}

extension MainTheme {
    @ViewBuilder
    var mainBackground: some View {
        switch self {
        case .liquidGlass:
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        case .breathing:
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 1.0),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        case .darkZen:
            Color(red: 0.06, green: 0.08, blue: 0.14)
                .ignoresSafeArea()
                .overlay(
                    Canvas { context, size in
                        for _ in 0..<40 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                with: .color(.white.opacity(0.08))
                            )
                        }
                    }
                )
        case .softDawn:
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.94, blue: 0.88),
                    Color(red: 0.95, green: 0.90, blue: 0.98),
                    Color(red: 0.88, green: 0.93, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    var meditateIcon: some View {
        switch self {
        case .liquidGlass:
            if #available(iOS 26.0, *) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "wind")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(.black)
                    }
                    .foregroundStyle(.primary)
                    .frame(width: 140, height: 140)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                }
                
            } else {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "wind")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(.black)
                    }
                    .foregroundStyle(.primary)
                    .frame(width: 180, height: 180)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                }
            }
            
        case .breathing:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan, .blue, .purple.opacity(0.8)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "wind")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .blue.opacity(0.35), radius: 24, y: 8)
            }
            
        case .softDawn:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
                }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.85, blue: 0.75),
                            Color(red: 0.85, green: 0.75, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "wind")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(.white)
                    }
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.orange.opacity(0.2), radius: 16, y: 8)
        }
            
        case .darkZen:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: 160 + CGFloat(i * 28), height: 160 + CGFloat(i * 28))
                }
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "wind")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}
