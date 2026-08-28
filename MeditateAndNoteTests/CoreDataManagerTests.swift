//
//  CoreDataManagerTests.swift
//  MeditateAndNoteTests
//

import CoreData
import XCTest
@testable import MeditateAndNote

final class CoreDataManagerTests: XCTestCase {

    func testModelContainsAllExpectedEntities() {
        let model = CoreDataManager(inMemory: true).container.managedObjectModel

        XCTAssertNotNil(model.entitiesByName[CDEntity.note])
        XCTAssertNotNil(model.entitiesByName[CDEntity.session])
        XCTAssertNotNil(model.entitiesByName[CDEntity.dailyActivity])
        XCTAssertNotNil(model.entitiesByName[CDEntity.streakMeta])
    }

    func testNoteEntityHasExpectedAttributes() {
        let model = CoreDataManager(inMemory: true).container.managedObjectModel
        let entity = model.entitiesByName[CDEntity.note]!

        XCTAssertEqual(entity.attributesByName["id"]?.attributeType, .UUIDAttributeType)
        XCTAssertEqual(entity.attributesByName["title"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["content"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["date"]?.attributeType, .dateAttributeType)

        XCTAssertEqual(entity.attributesByName["id"]?.isOptional, false)
        XCTAssertEqual(entity.attributesByName["title"]?.isOptional, false)
        XCTAssertEqual(entity.attributesByName["content"]?.isOptional, false)
        XCTAssertEqual(entity.attributesByName["date"]?.isOptional, false)
    }

    func testSessionEntityHasExpectedAttributes() {
        let model = CoreDataManager(inMemory: true).container.managedObjectModel
        let entity = model.entitiesByName[CDEntity.session]!

        XCTAssertEqual(entity.attributesByName["id"]?.attributeType, .UUIDAttributeType)
        XCTAssertEqual(entity.attributesByName["meditationId"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["completedAt"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(entity.attributesByName["duration"]?.attributeType, .doubleAttributeType)
    }

    func testDailyActivityUniqueConstraintOnDate() {
        let model = CoreDataManager(inMemory: true).container.managedObjectModel
        let entity = model.entitiesByName[CDEntity.dailyActivity]!

        let hasDateConstraint = entity.uniquenessConstraints.contains { constraint in
            (constraint as? [Any])?.contains { $0 as? String == "date" } == true
        }
        XCTAssertTrue(hasDateConstraint, "CDDailyActivity must declare date as a uniqueness constraint")
    }

    func testStreakMetaEntityHasExpectedAttributes() {
        let model = CoreDataManager(inMemory: true).container.managedObjectModel
        let entity = model.entitiesByName[CDEntity.streakMeta]!

        XCTAssertEqual(entity.attributesByName["currentStreak"]?.attributeType, .integer32AttributeType)
        XCTAssertEqual(entity.attributesByName["longestStreak"]?.attributeType, .integer32AttributeType)
        XCTAssertEqual(entity.attributesByName["lastCountedDay"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(entity.attributesByName["lastCountedDay"]?.isOptional, true)
    }

    func testInMemoryStoreLoadsPersistentStores() {
        let manager = CoreDataManager(inMemory: true)

        XCTAssertEqual(manager.container.persistentStoreCoordinator.persistentStores.count, 1)
        XCTAssertEqual(
            manager.container.persistentStoreCoordinator.persistentStores.first?.type,
            NSInMemoryStoreType
        )
    }
}