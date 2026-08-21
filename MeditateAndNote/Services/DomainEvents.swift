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
}

// MARK: - Concrete Domain Events

struct NoteCreated: DomainEvent {
    let note: Note
    let occurredAt: Date = Date()
}

struct NoteUpdated: DomainEvent {
    let note: Note
    let occurredAt: Date = Date()
}

struct NoteDeleted: DomainEvent {
    let noteId: NoteID
    let occurredAt: Date = Date()
}

struct MeditationCompleted: DomainEvent {
    let session: MeditationSession
    let occurredAt: Date = Date()
}

struct StreakChanged: DomainEvent {
    let currentStreak: Int
    let longestStreak: Int
    let occurredAt: Date = Date()
}

// MARK: - Event Publisher Protocol

protocol DomainEventPublisher: AnyObject {
    func publish(_ event: DomainEvent)
}

// MARK: - Event Subscriber Protocol

protocol DomainEventSubscriber: AnyObject {
    func handle(_ event: DomainEvent)
}

// MARK: - Simple In-Memory Event Bus

final class DomainEventBus: DomainEventPublisher {
    private var subscribers: [DomainEventSubscriber] = []
    private let queue = DispatchQueue(label: "domain.event.bus", attributes: .concurrent)
    
    func subscribe(_ subscriber: DomainEventSubscriber) {
        queue.async(flags: .barrier) { [weak self] in
            self?.subscribers.append(subscriber)
        }
    }
    
    func unsubscribe(_ subscriber: DomainEventSubscriber) {
        queue.async(flags: .barrier) { [weak self] in
            self?.subscribers.removeAll { $0 === subscriber }
        }
    }
    
    func publish(_ event: DomainEvent) {
        let snapshot = queue.sync { subscribers }
        snapshot.forEach { $0.handle(event) }
    }
}

// MARK: - Global Event Bus (for convenience)

extension DomainEventBus {
    static let shared = DomainEventBus()
}