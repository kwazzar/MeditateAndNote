//
//  EventLoopCoordinator.swift
//  MeditateAndNote
//

import Foundation

protocol DomainEventRouting {
    func handle(_ event: DomainEvent) async
}

/// Single consumer of the bus. Chain:
///
///     eventBus.publish(event)            // emitter's thread (e.g. NoteManager actor)
///     └─ AsyncStream<DomainEvent>.events // bus fans the event out to each consumer
///        └─ this Task (for await)        // cancellable
///           └─ handlers, on @MainActor   // handlers may mutate observable/CoreData state
///
/// Events are processed sequentially, in publish order. `handlers` is a closure
/// rather than an array so the container's scopes stay `lazy` — resolving them
/// up front would open every CoreData stack and load the models at launch.
final class EventLoopCoordinator {
    private var eventsTask: Task<Void, Never>?

    func start(
        eventBus: DomainEventPublisher = DomainEventBus.shared,
        handlers: @escaping @MainActor () -> [any DomainEventRouting]
    ) {
        stop()
        eventsTask = Task { @MainActor in
            for await event in eventBus.events {
                for handler in handlers() {
                    await handler.handle(event)
                }
            }
        }
    }

    func stop() {
        eventsTask?.cancel()
        eventsTask = nil
    }

    deinit {
        eventsTask?.cancel()
    }
}
