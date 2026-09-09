//
//  DomainEvents.swift
//  MeditateAndNote
//
//  Domain Events for decoupling bounded contexts.
//  Events are a closed sum type: every subscriber handles all cases via an
//  exhaustive switch, so adding a new event is a compile-time decision.
//

import Foundation

// MARK: - Telemetry Types (moved from AIDraftMetrics.swift)

enum ErrorKind: String, Codable, Sendable {
    case timeout
    case rateLimited
    case unavailable
    case emptyResponse
    case unknown
}

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

// MARK: - Domain Event (sum type)

enum DomainEvent: Sendable {
    case noteCreated(Note)
    case noteUpdated(Note)
    case noteDeleted(NoteID)
    case meditationCompleted(MeditationSession)
    case aiDraftGenerated(noteID: NoteID, sessionID: UUID)
    case aiDraftMetric(event: AIDraftMetric)
    case noteInsightsUpdated([NoteID])
}

// MARK: - Publisher Protocol

protocol DomainEventPublisher: AnyObject, Sendable {
    typealias Handler = @Sendable (DomainEvent) -> Void

    /// AsyncStream of published events, consumed sequentially via `for await`.
    var events: AsyncStream<DomainEvent> { get }

    /// Subscribes a handler and returns a token for unsubscribing.
    @discardableResult
    func subscribe(_ handler: @escaping Handler) -> UUID
    func unsubscribe(_ id: UUID)
    nonisolated func publish(_ event: DomainEvent)
}

// MARK: - Thread-Safe Subscription Storage

private final class Subscriptions: @unchecked Sendable {
    private var handlers: [UUID: @Sendable (DomainEvent) -> Void] = [:]
    private let lock = NSLock()

    func add(_ handler: @escaping @Sendable (DomainEvent) -> Void) -> UUID {
        let id = UUID()
        lock.withLock { handlers[id] = handler }
        return id
    }

    func remove(_ id: UUID) {
        _ = lock.withLock { handlers.removeValue(forKey: id) }
    }

    func callAsFunction(_ event: DomainEvent) {
        let snapshot = lock.withLock { Array(handlers.values) }
        snapshot.forEach { $0(event) }
    }
}

// MARK: - In-Memory Event Bus

final class DomainEventBus: DomainEventPublisher, @unchecked Sendable {
    private let storage = Subscriptions()
    private var streamContinuations: [UUID: AsyncStream<DomainEvent>.Continuation] = [:]
    private let streamLock = NSLock()

    var events: AsyncStream<DomainEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.streamLock.withLock { self.streamContinuations[id] = continuation }
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                _ = self.streamLock.withLock { self.streamContinuations.removeValue(forKey: id) }
            }
        }
    }

    @discardableResult
    func subscribe(_ handler: @escaping @Sendable (DomainEvent) -> Void) -> UUID {
        storage.add(handler)
    }

    func unsubscribe(_ id: UUID) {
        storage.remove(id)
    }

    nonisolated func publish(_ event: DomainEvent) {
        storage(event)
        let snapshot = streamLock.withLock { Array(streamContinuations.values) }
        snapshot.forEach { $0.yield(event) }
    }
}

// MARK: - Global Event Bus (for convenience)

extension DomainEventBus {
    static let shared = DomainEventBus()
}
