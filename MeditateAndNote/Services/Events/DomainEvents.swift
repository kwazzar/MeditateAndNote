//
//  DomainEvents.swift
//  MeditateAndNote
//
//  Domain Events for decoupling bounded contexts.
//  Events are a closed sum type: every subscriber handles all cases via an
//  exhaustive switch, so adding a new event is a compile-time decision.
//

import Foundation

// MARK: - Domain Event (sum type)

enum DomainEvent: Sendable {
    case noteCreated(Note)
    case noteUpdated(Note)
    case noteDeleted(NoteID)
    case meditationCompleted(MeditationSession)
    case aiDraftGenerated(noteID: NoteID, sessionID: UUID)
}

// MARK: - Publisher Protocol

protocol DomainEventPublisher: AnyObject, Sendable {
    typealias Handler = @Sendable (DomainEvent) -> Void

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

final class DomainEventBus: DomainEventPublisher {
    private let storage = Subscriptions()

    @discardableResult
    func subscribe(_ handler: @escaping @Sendable (DomainEvent) -> Void) -> UUID {
        storage.add(handler)
    }

    func unsubscribe(_ id: UUID) {
        storage.remove(id)
    }

    nonisolated func publish(_ event: DomainEvent) {
        storage(event)
    }
}

// MARK: - Global Event Bus (for convenience)

extension DomainEventBus {
    static let shared = DomainEventBus()
}
