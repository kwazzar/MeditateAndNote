//
//  AIDraftMetricStore.swift
//  MeditateAndNote
//
//  Persistence contract for AI draft telemetry events.
//  Append-only rows — no content captured, only typed event names and
//  numeric/duration fields. Follows the per-domain <X>Store shape.
//

import Foundation

// MARK: - Store Protocol

protocol AIDraftMetricStore: Sendable {
    func record(_ metric: AIDraftMetric) async throws
    func fetchAll() async throws -> [AIDraftMetric]
    func deleteAll() async throws
}

// MARK: - Domain Event Subscription

extension AIDraftMetricStore {
    /// Reacts to telemetry events published on the event bus. Ignored unless
    /// it is an AI draft metric, so a store can subscribe to the bus and only
    /// ever persist the shape it owns.
    func handle(_ event: DomainEvent) async {
        guard case let .aiDraftMetric(metric) = event else { return }
        try? await record(metric)
    }
}

// MARK: - In-Memory Implementation (tests + previews)

final actor InMemoryAIDraftMetricStore: AIDraftMetricStore {
    private var metrics: [AIDraftMetric]

    init(seed: [AIDraftMetric] = []) {
        self.metrics = seed
    }

    func record(_ metric: AIDraftMetric) async throws {
        metrics.append(metric)
    }

    func fetchAll() async throws -> [AIDraftMetric] {
        metrics
    }

    func deleteAll() async throws {
        metrics.removeAll()
    }
}
