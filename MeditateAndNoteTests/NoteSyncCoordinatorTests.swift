//
//  NoteSyncCoordinatorTests.swift
//  MeditateAndNoteTests
//
//  Created by Quasar on 04.09.2026.
//

import XCTest
@testable import MeditateAndNote

final class NoteSyncCoordinatorTests: XCTestCase {

    private func makeSUT(local: InMemoryNoteDataSource = InMemoryNoteDataSource(),
                         remote: InMemoryNoteDataSource = InMemoryNoteDataSource())
        -> DefaultNoteSyncCoordinator {
        DefaultNoteSyncCoordinator(local: local, remote: remote)
    }

    private func makeNote(_ title: NoteTitle) -> Note {
        Note(title: title, content: "body")
    }

    // MARK: - fetchAll

    func testFetchAll_localOnly_ignoresRemote() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L")])
        let remote = InMemoryNoteDataSource(seedNotes: [makeNote("R")])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.fetchAll(strategy: .localOnly)

        XCTAssertEqual(result.map(\.title.rawValue), ["L"])
    }

    func testFetchAll_remoteOnly_ignoresLocal() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L")])
        let remote = InMemoryNoteDataSource(seedNotes: [makeNote("R")])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.fetchAll(strategy: .remoteOnly)

        XCTAssertEqual(result.map(\.title.rawValue), ["R"])
    }

    func testFetchAll_localFirst_returnsLocalWhenNonEmpty() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L1"), makeNote("L2")])
        let remote = InMemoryNoteDataSource(seedNotes: [makeNote("R")])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.fetchAll(strategy: .localFirst)

        XCTAssertEqual(result.map(\.title.rawValue), ["L1", "L2"])
    }

    func testFetchAll_localFirst_fallsBackToRemoteWhenEmpty() async throws {
        let remote = InMemoryNoteDataSource(seedNotes: [makeNote("R")])
        let sut = makeSUT(remote: remote)

        let result = try await sut.fetchAll(strategy: .localFirst)

        XCTAssertEqual(result.map(\.title.rawValue), ["R"])
    }

    func testFetchAll_remoteFirst_returnsRemoteWhenNonEmpty() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L")])
        let remote = InMemoryNoteDataSource(seedNotes: [makeNote("R")])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.fetchAll(strategy: .remoteFirst)

        XCTAssertEqual(result.map(\.title.rawValue), ["R"])
    }

    func testFetchAll_remoteFirst_fallsBackToLocalWhenEmpty() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L")])
        let sut = makeSUT(local: local)

        let result = try await sut.fetchAll(strategy: .remoteFirst)

        XCTAssertEqual(result.map(\.title.rawValue), ["L"])
    }

    func testFetchAll_hybrid_mergesDeduplicatingByID() async throws {
        let shared = makeNote("shared")
        let local = InMemoryNoteDataSource(seedNotes: [shared, makeNote("local-only")])
        let remote = InMemoryNoteDataSource(seedNotes: [shared, makeNote("remote-only")])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.fetchAll(strategy: .hybrid)

        XCTAssertEqual(result.count, 3, "Hybrid must dedupe by id")
        XCTAssertTrue(result.contains(where: { $0.id == shared.id }))
    }

    // MARK: - find

    func testFind_localOnly_returnsLocal() async throws {
        let note = makeNote("L")
        let local = InMemoryNoteDataSource(seedNotes: [note])
        let sut = makeSUT(local: local)

        let result = try await sut.find(note.id, strategy: .localOnly)

        XCTAssertEqual(result, note)
    }

    func testFind_localFirst_fallsBackToRemote() async throws {
        let note = makeNote("R")
        let remote = InMemoryNoteDataSource(seedNotes: [note])
        let sut = makeSUT(remote: remote)

        let result = try await sut.find(note.id, strategy: .localFirst)

        XCTAssertEqual(result, note)
    }

    func testFind_remoteFirst_fallsBackToLocal() async throws {
        let note = makeNote("L")
        let local = InMemoryNoteDataSource(seedNotes: [note])
        let sut = makeSUT(local: local)

        let result = try await sut.find(note.id, strategy: .remoteFirst)

        XCTAssertEqual(result, note)
    }

    func testFind_hybrid_prefersRemote() async throws {
        let local = InMemoryNoteDataSource(seedNotes: [makeNote("L")])
        let remoteNote = makeNote("R")
        let remote = InMemoryNoteDataSource(seedNotes: [remoteNote])
        let sut = makeSUT(local: local, remote: remote)

        let result = try await sut.find(remoteNote.id, strategy: .hybrid)

        XCTAssertEqual(result, remoteNote)
    }

    func testFind_returnsNilWhenAbsent() async throws {
        let sut = makeSUT()

        let result = try await sut.find(NoteID(), strategy: .localOnly)

        XCTAssertNil(result)
    }

    // MARK: - save

    func testSave_localOnly_writesOnlyLocal() async throws {
        let local = InMemoryNoteDataSource()
        let remote = InMemoryNoteDataSource()
        let sut = makeSUT(local: local, remote: remote)
        let note = makeNote("L")

        try await sut.save(note, strategy: .localOnly)

        let localNotes = try await local.fetchAll()
        let remoteNotes = try await remote.fetchAll()
        XCTAssertEqual(localNotes, [note])
        XCTAssertTrue(remoteNotes.isEmpty)
    }

    func testSave_remoteOnly_writesOnlyRemote() async throws {
        let local = InMemoryNoteDataSource()
        let remote = InMemoryNoteDataSource()
        let sut = makeSUT(local: local, remote: remote)
        let note = makeNote("R")

        try await sut.save(note, strategy: .remoteOnly)

        let localNotes = try await local.fetchAll()
        let remoteNotes = try await remote.fetchAll()
        XCTAssertTrue(localNotes.isEmpty)
        XCTAssertEqual(remoteNotes, [note])
    }

    func testSave_hybrid_writesBoth() async throws {
        let local = InMemoryNoteDataSource()
        let remote = InMemoryNoteDataSource()
        let sut = makeSUT(local: local, remote: remote)
        let note = makeNote("H")

        try await sut.save(note, strategy: .hybrid)

        let localNotes = try await local.fetchAll()
        let remoteNotes = try await remote.fetchAll()
        XCTAssertEqual(localNotes, [note])
        XCTAssertEqual(remoteNotes, [note])
    }

    // MARK: - delete

    func testDelete_localOnly_deletesOnlyLocal() async throws {
        let note = makeNote("X")
        let local = InMemoryNoteDataSource(seedNotes: [note])
        let remote = InMemoryNoteDataSource(seedNotes: [note])
        let sut = makeSUT(local: local, remote: remote)

        try await sut.delete(note.id, strategy: .localOnly)

        let localNotes = try await local.fetchAll()
        let remoteNotes = try await remote.fetchAll()
        XCTAssertTrue(localNotes.isEmpty)
        XCTAssertEqual(remoteNotes, [note])
    }

    func testDelete_hybrid_deletesBoth() async throws {
        let note = makeNote("X")
        let local = InMemoryNoteDataSource(seedNotes: [note])
        let remote = InMemoryNoteDataSource(seedNotes: [note])
        let sut = makeSUT(local: local, remote: remote)

        try await sut.delete(note.id, strategy: .hybrid)

        let localNotes = try await local.fetchAll()
        let remoteNotes = try await remote.fetchAll()
        XCTAssertTrue(localNotes.isEmpty)
        XCTAssertTrue(remoteNotes.isEmpty)
    }
}