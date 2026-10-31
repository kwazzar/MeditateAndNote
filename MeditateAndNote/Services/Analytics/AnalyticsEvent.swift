//
//  AnalyticsEvent.swift
//  MeditateAndNote
//

import Foundation

/// Provider-independent analytics payload. Firebase mapping stays in the
/// infrastructure adapter, so the domain/event mapper has no SDK dependency.
struct AnalyticsEvent: Equatable, Sendable {
    enum Value: Equatable, Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
    }

    let name: String
    let parameters: [String: Value]

    init(name: String, parameters: [String: Value] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}
