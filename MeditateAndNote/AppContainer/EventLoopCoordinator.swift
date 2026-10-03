//
//  EventLoopCoordinator.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore

protocol DomainEventRouting {
    func handle(_ event: DomainEvent) async

    /// Whether this scope reacts to `event` at all. Static and allocation-free
    /// on purpose: `AppContainer.handlers(for:)` calls it *before* touching the
    /// scope's `lazy` backing, which is what keeps an unhandled event from
    /// building the CoreData stacks and models behind it. Must stay in sync
    /// with `handle(_:)` — the compiler enforces that for the enum cases, but
    /// not for this filter, so a new case means updating both.
    static func handles(_ event: DomainEvent) -> Bool
}

/// Single consumer of the bus. Chain:
///
///     eventBus.publish(event)            // emitter's thread (e.g. NoteManager actor)
///     └─ AsyncStream<DomainEvent>.events // bus fans the event out to each consumer
///        └─ this Task (for await)        // cancellable
///           └─ handlers, on @MainActor   // handlers may mutate observable/CoreData state
///
/// Events are processed sequentially, in publish order. `handlers` is a closure
/// rather than an array so the container's scopes stay `lazy` — it takes the
/// event and returns only the scopes that react to it, so a `.noteInsightsUpdated`
/// (which no scope mutates on) builds nothing at all.
final class EventLoopCoordinator {
    private var eventsTask: Task<Void, Never>?

    func start(
        eventBus: DomainEventPublisher = DomainEventBus.shared,
        handlers: @escaping @MainActor (DomainEvent) -> [any DomainEventRouting]
    ) {
        stop()
        eventsTask = Task { @MainActor in
            for await event in eventBus.events {
                for handler in handlers(event) {
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
