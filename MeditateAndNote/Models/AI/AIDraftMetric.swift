//
//  AIDraftMetric.swift
//  MeditateAndNote
//
//  Domain value objects for draft telemetry. Privacy-sandboxed by design:
//  only counts, latency and a typed ErrorKind are recorded — never prompt
//  text, suggestions, or raw provider messages.
//

import Foundation

// MARK: - ErrorKind

enum ErrorKind: String, Codable, Sendable {
    case timeout
    case rateLimited
    case unavailable
    case emptyResponse
    case unknown
}

// MARK: - AIDraftMetric

enum AIDraftMetric: Equatable, Sendable, Codable {
    case generationStarted(warmCold: Bool)
    case generationCompleted(latencyMs: Int, suggestionCount: Int)
    case generationFailed(errorKind: ErrorKind)
    case suggestionInserted(index: Int)
    case suggestionRejected(index: Int)
}

extension AIDraftMetric {
    /// Stable scalar label for cheap Core Data rollups (avoids decoding every
    /// payload JSON blob just to bucket events by type).
    var kindRawValue: String {
        switch self {
        case .generationStarted: return "generationStarted"
        case .generationCompleted: return "generationCompleted"
        case .generationFailed: return "generationFailed"
        case .suggestionInserted: return "suggestionInserted"
        case .suggestionRejected: return "suggestionRejected"
        }
    }
}
