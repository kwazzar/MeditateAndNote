//
//  DomainEvents.swift
//  MeditateAndNote
//
//  Domain Events for decoupling bounded contexts
//

import Foundation

// MARK: - Domain Event Protocol

protocol DomainEvent {
    var occurredAt: Date { get }
    func accept(_ visitor: DomainEventVisitor)
}

// MARK: - Concrete Domain Events

struct NoteCreated: DomainEvent {
    let date: Date
    let occurredAt: Date = Date()

    func accept(_ visitor: DomainEventVisitor) { visitor.visit(self) }
}

struct NoteUpdated: DomainEvent {
    let date: Date
    let occurredAt: Date = Date()

    func accept(_ visitor: DomainEventVisitor) { visitor.visit(self) }
}

struct NoteDeleted: DomainEvent {
    let noteId: NoteID
    let occurredAt: Date = Date()

    func accept(_ visitor: DomainEventVisitor) { visitor.visit(self) }
}

struct MeditationCompleted: DomainEvent {
    let session: MeditationSession
    let occurredAt: Date = Date()

    func accept(_ visitor: DomainEventVisitor) { visitor.visit(self) }
}

struct StreakChanged: DomainEvent {
    let currentStreak: Int
    let longestStreak: Int
    let occurredAt: Date = Date()

    func accept(_ visitor: DomainEventVisitor) { visitor.visit(self) }
}

// MARK: - Event Visitor Protocol

protocol DomainEventVisitor: AnyObject {
    func visit(_ event: NoteCreated)
    func visit(_ event: NoteUpdated)
    func visit(_ event: NoteDeleted)
    func visit(_ event: MeditationCompleted)
    func visit(_ event: StreakChanged)
}

// MARK: - Event Publisher Protocol

protocol DomainEventPublisher: AnyObject {
    func publish(_ event: DomainEvent)
}

// MARK: - Simple In-Memory Event Bus

final class DomainEventBus: DomainEventPublisher {
    private var visitors: [DomainEventVisitor] = []
    private let queue = DispatchQueue(label: "domain.event.bus", attributes: .concurrent)

    func subscribe(_ visitor: DomainEventVisitor) {
        queue.async(flags: .barrier) { [weak self] in
            self?.visitors.append(visitor)
        }
    }

    func unsubscribe(_ visitor: DomainEventVisitor) {
        queue.async(flags: .barrier) { [weak self] in
            self?.visitors.removeAll { $0 === visitor }
        }
    }

    func publish(_ event: DomainEvent) {
        let snapshot = queue.sync { visitors }
        snapshot.forEach { event.accept($0) }
    }
}

// MARK: - Global Event Bus (for convenience)

extension DomainEventBus {
    static let shared = DomainEventBus()
}
