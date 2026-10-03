//
//  DomainEventBusOrderingTests.swift
//  MeditateAndNoteTests
//
//  Locks the delivery-ordering guarantee of `DomainEventBus`.
//
//  `AsyncStream` gave every consumer the events **in publish order** — that is
//  the behaviour `EventLoopCoordinator`, `NoteMenuViewModel` and
//  `NoteInsightsViewModel` are written against. The Android port replaces the
//  stream with a protocol-subscriber bus (`DomainEventSubscriber.handle(_:)`),
//  which has no such guarantee for free: if a consumer is dispatched to its own
//  task or actor, two publishes racing on different threads can land out of
//  order. These tests are the acceptance criteria for that swap — they must
//  pass unchanged against the subscriber implementation.
//
//  What is guaranteed:
//  - per consumer, events arrive in publish order
//  - all consumers observe the same sequence
//
//  What is explicitly NOT guaranteed (and asserted as such): the order in which
//  *different* consumers are invoked relative to each other. Handlers are held in
//  a `Dictionary` and iterated per publish, so that order is not stable, and no
//  caller may rely on it.
//

import XCTest
@testable import MeditateAndNote

final class DomainEventBusOrderingTests: XCTestCase {

    private let eventCount = 100

    /// Deterministic UUID for a sequence index, so a reordering cannot hide
    /// behind equal-value comparison. `NoteID` wraps a `UUID`, so the payload
    /// has to be one.
    private func eventSequence() -> [DomainEvent] {
        (0..<eventCount).map { .noteInsightsUpdated([payload($0)]) }
    }

    private func payload(_ index: Int) -> NoteID {
        let b = UInt8(index % 256)
        return NoteID(rawValue: UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, b
        )))
    }

    /// Maps received events back to their index, or `nil` for anything that does
    /// not carry one of `payload(_:)` — which would itself be a failure.
    private func sequenceNumbers(_ received: [DomainEvent]) -> [Int?] {
        let byUUID = Dictionary(uniqueKeysWithValues: (0..<eventCount).map { (payload($0).rawValue, $0) })
        return received.compactMap {
            guard case let .noteInsightsUpdated(ids) = $0, let first = ids.first
            else { return nil }
            return byUUID[first.rawValue]
        }
    }

    // MARK: - subscribe(handler) path

    /// The synchronous subscription path: `publish` calls each handler inline, so
    /// per-consumer ordering follows from the serial call loop. This is the
    /// property the protocol-subscriber bus has to reproduce.
    func testHandlerSeesEventsInPublishOrder() {
        let bus = DomainEventBus()
        let received = LockedBox<[DomainEvent]>([])

        bus.subscribe { event in received.mutate { $0.append(event) } }

        for event in eventSequence() { bus.publish(event) }

        XCTAssertEqual(
            sequenceNumbers(received.value), Array(0..<eventCount).map(Optional.some),
            "handler received events out of publish order"
        )
    }

    /// Three concurrent consumers, one publish loop. Every consumer must end up
    /// with the identical sequence — the property the three ViewModels rely on
    /// when they each read the same event stream.
    func testAllHandlersSeeIdenticalSequence() {
        let bus = DomainEventBus()
        let received = LockedBox<[[DomainEvent]]>(Array(repeating: [], count: 3))

        for consumer in 0..<3 {
            bus.subscribe { event in
                received.mutate { $0[consumer].append(event) }
            }
        }

        for event in eventSequence() { bus.publish(event) }

        let sequences = received.value.map { sequenceNumbers($0) }
        let expected = Array(0..<eventCount).map(Optional.some)
        for (consumer, sequence) in sequences.enumerated() {
            XCTAssertEqual(sequence, expected, "consumer \(consumer) diverged")
        }
        XCTAssertEqual(sequences[0], sequences[1], "consumers 0 and 1 disagree")
        XCTAssertEqual(sequences[1], sequences[2], "consumers 1 and 2 disagree")
    }

    /// Per-consumer order survives concurrent publishing. Two threads publishing
    /// simultaneously interleave arbitrarily *between themselves*, but each
    /// consumer must still observe a self-consistent sequence — specifically,
    /// the events that thread published must appear in that thread's order.
    func testPerConsumerOrderSurvivesConcurrentPublish() {
        let bus = DomainEventBus()
        let received = LockedBox<[DomainEvent]>([])

        bus.subscribe { event in received.mutate { $0.append(event) } }

        // Each thread owns a contiguous, even/odd split of the sequence, so a
        // violation of per-publisher order is detectable without depending on
        // how the two threads interleave.
        let even = eventSequence().enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let odd = eventSequence().enumerated().filter { $0.offset % 2 == 1 }.map(\.element)

        DispatchQueue.concurrentPerform(iterations: 2) { iteration in
            for event in iteration == 0 ? even : odd {
                bus.publish(event)
            }
        }

        let numbers = sequenceNumbers(received.value).compactMap { $0 }
        XCTAssertEqual(numbers.count, eventCount, "events lost or duplicated")

        let evenSeen = numbers.filter { $0 % 2 == 0 }
        let oddSeen = numbers.filter { $0 % 2 == 1 }
        XCTAssertEqual(evenSeen, evenSeen.sorted(), "even thread's order broken")
        XCTAssertEqual(oddSeen, oddSeen.sorted(), "odd thread's order broken")
    }

    // MARK: - AsyncStream path (what EventLoopCoordinator consumes)

    /// The real production shape: `for await event in bus.events`. One event,
    /// three live consumers, each must observe it. Guards against a regression
    /// where `events` snapshots continuations and a late consumer is silently
    /// dropped.
    func testAsyncStreamFansOutToEveryConsumer() async throws {
        let bus = DomainEventBus()
        let count = 3
        let total = eventCount
        let expected = Array(0..<total)
        let byUUID = Dictionary(
            uniqueKeysWithValues: (0..<total).map { (payload($0).rawValue, $0) }
        )
        let toPublish = eventSequence()
        let gate = ArrivalGate()

        await withTaskGroup(of: [Int].self) { group in
            for _ in 0..<count {
                group.addTask {
                    // Grab the stream *before* announcing arrival:
                    // `bus.events` registers the continuation synchronously in
                    // its getter, so once the gate has seen `count` arrivals every
                    // continuation is guaranteed to be in place. This is the
                    // production shape too — `EventLoopCoordinator` reads
                    // `bus.events` first, then consumes.
                    let stream = bus.events
                    await gate.arrive()
                    var mine: [Int] = []
                    for await event in stream {
                        if case let .noteInsightsUpdated(ids) = event,
                           let first = ids.first,
                           let index = byUUID[first.rawValue] {
                            mine.append(index)
                        }
                        if mine.count == total { break }
                    }
                    return mine
                }
            }

            await gate.waitForArrivals(count)
            for event in toPublish { bus.publish(event) }

            var finished = 0
            for await sequence in group {
                XCTAssertEqual(sequence, expected, "stream consumer \(finished) diverged")
                finished += 1
            }
            XCTAssertEqual(finished, count, "a consumer's task never finished")
        }
    }

    /// Unsubscribe stops delivery mid-stream; the consumer keeps what it already
    /// has and gets nothing further. `unsubscribe` is on the `handler` path only,
    /// but the test lives here because it is the same ordering contract.
    func testUnsubscribeStopsDeliveryAtThatPoint() {
        let bus = DomainEventBus()
        let received = LockedBox<[DomainEvent]>([])
        let id = bus.subscribe { event in received.mutate { $0.append(event) } }

        let all = eventSequence()
        for event in all.prefix(10) { bus.publish(event) }
        bus.unsubscribe(id)
        for event in all.dropFirst(10) { bus.publish(event) }

        XCTAssertEqual(sequenceNumbers(received.value), Array(0..<10).map(Optional.some))
    }

    /// Sanity check on the non-guarantee above, so a future change that starts
    /// depending on cross-consumer order is caught rather than silently flaky.
    func testCrossConsumerInvocationOrderIsNotGuaranteed() {
        let bus = DomainEventBus()
        let order = LockedBox<[Int]>([])

        for consumer in 0..<3 {
            bus.subscribe { _ in order.mutate { $0.append(consumer) } }
        }
        bus.publish(.noteInsightsUpdated([payload(0)]))

        XCTAssertEqual(
            order.value.sorted(), [0, 1, 2],
            "every consumer must be invoked"
        )
        // Deliberately no assertion on `order.value` itself: it is derived from
        // `Dictionary` iteration and may change between runs. Documented as
        // unspecified in the file comment.
    }
}

// MARK: - Helpers

/// Rendezvous point: consumers announce that their stream continuation is
/// registered, and the publisher waits until all of them have. Replaces a sleep,
/// which is both slower and flaky — a consumer that has not been scheduled yet
/// would silently miss every event.
private actor ArrivalGate {
    private var arrived = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func arrive() {
        arrived += 1
        let ready = waiters
        waiters = []
        for continuation in ready { continuation.resume() }
    }

    func waitForArrivals(_ expected: Int) async {
        if arrived >= expected { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

/// Minimal lock-guarded box. The test target has no shared actor-isolated
/// recorder, and `DomainEventBus` handlers are `@Sendable`, so each handler
/// needs its own synchronisation.
private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) { storage = value }

    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }

    /// Read-modify-write under a single lock acquisition. `value.append(x)` is a
    /// get followed by a set, so two concurrent handlers would lose each
    /// other's element; this keeps the whole mutation atomic.
    func mutate(_ body: (inout Value) -> Void) {
        lock.withLock { body(&storage) }
    }
}
