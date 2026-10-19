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

public enum ErrorKind: String, Codable, Sendable {
    case timeout
    case rateLimited
    case unavailable
    case emptyResponse
    case unknown
}

// MARK: - AIDraftMetric

public enum AIDraftMetric: Equatable, Sendable, Codable {
    case generationStarted(warmCold: Bool)
    case generationCompleted(latencyMs: Int, suggestionCount: Int)
    case generationFailed(errorKind: ErrorKind)
    case suggestionInserted(index: Int)
    case suggestionRejected(index: Int)
}

public extension AIDraftMetric {
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

public extension AIDraftError {
    /// The sanitized telemetry kind for this error.
    ///
    /// A metric row must never carry provider text, so the error is bucketed
    /// into a closed set of kinds instead of its message.
    var metricKind: ErrorKind {
        switch self {
        case .noContext, .contextTooLong, .providerUnavailable: return .unavailable
        case .rateLimited, .freeQuotaExhausted: return .rateLimited
        case .emptyResponse: return .emptyResponse
        case .cancelled, .noAcceptedProposals: return .unknown
        }
    }
}
