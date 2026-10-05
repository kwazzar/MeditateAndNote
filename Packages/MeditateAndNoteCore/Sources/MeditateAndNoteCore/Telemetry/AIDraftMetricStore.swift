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

public protocol AIDraftMetricStore: Sendable {
    func record(_ metric: AIDraftMetric) async throws
    func fetchAll() async throws -> [AIDraftMetric]
    func deleteAll() async throws
}

// MARK: - Domain Event Subscription

/// Reacts to telemetry events published on the event bus. Ignored unless it is
/// an AI draft metric, so a store can subscribe to the bus and only ever persist
/// the shape it owns.
///
/// A free function rather than a protocol extension: jextract emits protocol
/// extension members as *abstract* interface methods, which makes every
/// generated implementation fail to compile with "does not override abstract
/// method handle(DomainEvent)". Implementing conformances to this protocol in
/// Kotlin is the whole point of the Android port, so the shared logic lives here
/// and conformances forward to it.
public func handleAIDraftMetricEvent(
    _ event: DomainEvent,
    recording record: @Sendable (AIDraftMetric) async throws -> Void
) async {
    guard case let .aiDraftMetric(metric) = event else { return }
    try? await record(metric)
}

// MARK: - In-Memory Implementation (tests + previews)

public final actor InMemoryAIDraftMetricStore: AIDraftMetricStore {
    private var metrics: [AIDraftMetric]

    public init(seed: [AIDraftMetric] = []) {
        self.metrics = seed
    }

    public func record(_ metric: AIDraftMetric) async throws {
        metrics.append(metric)
    }

    public func fetchAll() async throws -> [AIDraftMetric] {
        metrics
    }

    public func deleteAll() async throws {
        metrics.removeAll()
    }

    public func handle(_ event: DomainEvent) async {
        await handleAIDraftMetricEvent(event) { try await self.record($0) }
    }
}
