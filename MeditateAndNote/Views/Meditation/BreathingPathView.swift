//
//  BreathingPathView.swift
//  MeditateAndNote
//
//  Created by kwazzar on 25.08.2026.
//

import SwiftUI

struct BreathingPathView: View {
    let phases: [BreathingPhase]
    let phaseIndex: Int
    let phaseProgress: Double
    var lineColor: Color = .primary
    var progressColor: Color = .orange
    var ballColor: Color = .orange
    var height: CGFloat = 280
    var widthPerSecond: CGFloat = 25
    
    var body: some View {
        ZStack {
            fullPath
                .stroke(lineColor.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            
            progressPath
                .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            
            Circle()
                .fill(ballColor)
                .frame(width: 40, height: 40)
                .position(ballPosition)
        }
        .frame(width: totalWidth, height: height)
        .animation(.linear(duration: 0.1), value: phaseProgress)
    }
}

private extension BreathingPathView {
    private struct PathSegment {
        let start: CGPoint
        let end: CGPoint
        let type: BreathingPhaseType
    }
    
    private var segments: [PathSegment] {
        var result: [PathSegment] = []
        var x: CGFloat = 0
        var y: CGFloat = height
        
        for phase in phases {
            let startPoint = CGPoint(x: x, y: y)
            x += CGFloat(phase.duration) * widthPerSecond
            switch phase.type {
            case .inhale: y = 0
            case .exhale: y = height
            case .holdAfterInhale, .holdAfterExhale: break
            }
            let endPoint = CGPoint(x: x, y: y)
            result.append(PathSegment(start: startPoint, end: endPoint, type: phase.type))
        }
        return result
    }
    
    private var totalWidth: CGFloat {
        CGFloat(phases.reduce(0) { $0 + $1.duration }) * widthPerSecond
    }
    
    /// Повна лінія патерну — завжди видна, статична геометрія.
    private var fullPath: Path {
        var path = Path()
        guard let first = segments.first else { return path }
        path.move(to: first.start)
        for segment in segments {
            switch segment.type {
            case .inhale, .exhale:
                let midX = (segment.start.x + segment.end.x) / 2
                let control1 = CGPoint(x: midX, y: segment.start.y)
                let control2 = CGPoint(x: midX, y: segment.end.y)
                path.addCurve(to: segment.end, control1: control1, control2: control2)
            case .holdAfterInhale, .holdAfterExhale:
                path.addLine(to: segment.end)
            }
        }
        return path
    }
    
    /// Прогрес-лінія: точно повторює логіку ballPosition — жодного arc-length trim.
    private var progressPath: Path {
        var path = Path()
        guard segments.indices.contains(phaseIndex) else { return fullPath }
        path.move(to: segments[0].start)
        
        // Всі попередні сегменти — повністю
        for i in 0..<phaseIndex {
            let seg = segments[i]
            addSegment(seg, to: &path)
        }
        
        // Поточний сегмент — лише частина до phaseProgress
        let current = segments[phaseIndex]
        switch current.type {
        case .inhale, .exhale:
            let midX = (current.start.x + current.end.x) / 2
            let control1 = CGPoint(x: midX, y: current.start.y)
            let control2 = CGPoint(x: midX, y: current.end.y)
            let (subControl1, subControl2, subEnd) = splitCubic(
                t: phaseProgress,
                p0: current.start, p1: control1, p2: control2, p3: current.end
            )
            path.addCurve(to: subEnd, control1: subControl1, control2: subControl2)
        case .holdAfterInhale, .holdAfterExhale:
            let x = current.start.x + (current.end.x - current.start.x) * CGFloat(phaseProgress)
            path.addLine(to: CGPoint(x: x, y: current.start.y))
        }
        
        return path
    }
    
    private func addSegment(_ segment: PathSegment, to path: inout Path) {
        switch segment.type {
        case .inhale, .exhale:
            let midX = (segment.start.x + segment.end.x) / 2
            let control1 = CGPoint(x: midX, y: segment.start.y)
            let control2 = CGPoint(x: midX, y: segment.end.y)
            path.addCurve(to: segment.end, control1: control1, control2: control2)
        case .holdAfterInhale, .holdAfterExhale:
            path.addLine(to: segment.end)
        }
    }
    
    private var ballPosition: CGPoint {
        guard segments.indices.contains(phaseIndex) else {
            return segments.last?.end ?? .zero
        }
        let seg = segments[phaseIndex]
        switch seg.type {
        case .inhale, .exhale:
            let midX = (seg.start.x + seg.end.x) / 2
            let control1 = CGPoint(x: midX, y: seg.start.y)
            let control2 = CGPoint(x: midX, y: seg.end.y)
            return cubicPoint(t: phaseProgress, p0: seg.start, p1: control1, p2: control2, p3: seg.end)
        case .holdAfterInhale, .holdAfterExhale:
            let x = seg.start.x + (seg.end.x - seg.start.x) * CGFloat(phaseProgress)
            return CGPoint(x: x, y: seg.start.y)
        }
    }
    
    private func cubicPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
    
    /// Розбиває кубічну криву Без'є на [0, t] через алгоритм де Кастельжо —
    /// дає control points і кінцеву точку часткової кривої, точно збігається з ballPosition.
    private func splitCubic(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> (CGPoint, CGPoint, CGPoint) {
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * CGFloat(t), y: a.y + (b.y - a.y) * CGFloat(t))
        }
        let p01 = lerp(p0, p1, t)
        let p12 = lerp(p1, p2, t)
        let p23 = lerp(p2, p3, t)
        let p012 = lerp(p01, p12, t)
        let p123 = lerp(p12, p23, t)
        let p0123 = lerp(p012, p123, t)
        return (p01, p012, p0123)
    }
}
