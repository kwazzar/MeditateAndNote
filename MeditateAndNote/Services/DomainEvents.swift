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
}

// MARK: - Publisher Protocol

protocol DomainEventPublisher: AnyObject {
    typealias Handler = @Sendable (DomainEvent) -> Void

    /// Subscribes a handler and returns a token for unsubscribing.
    @discardableResult
    func subscribe(_ handler: @escaping Handler) -> UUID
    func unsubscribe(_ id: UUID)
    func publish(_ event: DomainEvent)
}

// MARK: - Thread-Safe In-Memory Event Bus

final class DomainEventBus: DomainEventPublisher, @unchecked Sendable {
    typealias Handler = @Sendable (DomainEvent) -> Void

    private struct Subscription {
        let id: UUID
        let handler: Handler
    }

    private var subscriptions: [Subscription] = []
    private let queue = DispatchQueue(label: "domain.event.bus", attributes: .concurrent)

    /// Subscribes a handler and returns a token for unsubscribing.
    @discardableResult
    func subscribe(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        queue.async(flags: .barrier) { [weak self] in
            self?.subscriptions.append(Subscription(id: id, handler: handler))
        }
        return id
    }

    func unsubscribe(_ id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?.subscriptions.removeAll { $0.id == id }
        }
    }

    func publish(_ event: DomainEvent) {
        let snapshot = queue.sync { subscriptions }
        snapshot.forEach { $0.handler(event) }
    }
}

// MARK: - Global Event Bus (for convenience)

extension DomainEventBus {
    static let shared = DomainEventBus()
}
