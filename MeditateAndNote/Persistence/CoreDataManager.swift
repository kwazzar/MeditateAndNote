//
//  CoreDataManager.swift
//  MeditateAndNote
//
//  Programmatic Core Data stack — no .xcdatamodeld file.
//

import CoreData
import Foundation
import OSLog

// MARK: - Entity Names (constants for KVC / fetch requests)

enum CDEntity {
    static let note = "CDNote"
    static let session = "CDMeditationSession"
    static let dailyActivity = "CDDailyActivity"
    static let streakMeta = "CDStreakMeta"
    static let aiDraftSession = "CDAIDraftSession"
    static let aiDraftMetric = "CDAIDraftMetric"
}

// MARK: - CoreDataManager

final class CoreDataManager {

    static let shared = CoreDataManager()

    private let logger = Logger(subsystem: Config.bundleID, category: "CoreData")

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    convenience init() {
        self.init(inMemory: false)
    }

    /// Creates a Core Data stack.
    /// - Parameter inMemory: when `true`, uses an in-memory store (tests, previews).
    init(inMemory: Bool = false) {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: "MeditateAndNote", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { [logger] storeDescription, error in
            if let error {
                logger.error("Core Data store failed to load — \(error.localizedDescription)")

                // Fall back to an in-memory store so the app stays usable
                // for the current session instead of crashing at launch.
                let description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
                self.container.persistentStoreDescriptions = [description]

                self.container.loadPersistentStores { description, fallbackError in
                    if let fallbackError {
                        logger.error("In-memory fallback also failed — \(fallbackError.localizedDescription)")
                        fatalError("Unresolved Core Data error: \(fallbackError)")
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Background context helper

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Programmatic Model Builder

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── CDNote ──────────────────────────────────────────────
        let noteEntity = NSEntityDescription()
        noteEntity.name = CDEntity.note
        noteEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let noteID = NSAttributeDescription()
        noteID.name = "id"
        noteID.attributeType = .UUIDAttributeType
        noteID.isOptional = false

        let noteTitle = NSAttributeDescription()
        noteTitle.name = "title"
        noteTitle.attributeType = .stringAttributeType
        noteTitle.isOptional = false
        noteTitle.defaultValue = ""

        let noteContent = NSAttributeDescription()
        noteContent.name = "content"
        noteContent.attributeType = .stringAttributeType
        noteContent.isOptional = false
        noteContent.defaultValue = ""

        let noteDate = NSAttributeDescription()
        noteDate.name = "date"
        noteDate.attributeType = .dateAttributeType
        noteDate.isOptional = false
        noteDate.defaultValue = Date.distantPast

        noteEntity.properties = [noteID, noteTitle, noteContent, noteDate]

        // ── CDMeditationSession ─────────────────────────────────
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = CDEntity.session
        sessionEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let sessionID = NSAttributeDescription()
        sessionID.name = "id"
        sessionID.attributeType = .UUIDAttributeType
        sessionID.isOptional = false

        let sessionMeditationID = NSAttributeDescription()
        sessionMeditationID.name = "meditationId"
        sessionMeditationID.attributeType = .stringAttributeType
        sessionMeditationID.isOptional = false
        sessionMeditationID.defaultValue = ""

        let sessionCompletedAt = NSAttributeDescription()
        sessionCompletedAt.name = "completedAt"
        sessionCompletedAt.attributeType = .dateAttributeType
        sessionCompletedAt.isOptional = false
        sessionCompletedAt.defaultValue = Date.distantPast

        let sessionDuration = NSAttributeDescription()
        sessionDuration.name = "duration"
        sessionDuration.attributeType = .doubleAttributeType
        sessionDuration.isOptional = false
        sessionDuration.defaultValue = 0.0

        sessionEntity.properties = [sessionID, sessionMeditationID, sessionCompletedAt, sessionDuration]

        // ── CDDailyActivity ─────────────────────────────────────
        let activityEntity = NSEntityDescription()
        activityEntity.name = CDEntity.dailyActivity
        activityEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let activityDate = NSAttributeDescription()
        activityDate.name = "date"
        activityDate.attributeType = .dateAttributeType
        activityDate.isOptional = false
        activityDate.defaultValue = Date.distantPast

        let activityHasMeditation = NSAttributeDescription()
        activityHasMeditation.name = "hasMeditation"
        activityHasMeditation.attributeType = .booleanAttributeType
        activityHasMeditation.isOptional = false
        activityHasMeditation.defaultValue = false

        let activityHasNote = NSAttributeDescription()
        activityHasNote.name = "hasNote"
        activityHasNote.attributeType = .booleanAttributeType
        activityHasNote.isOptional = false
        activityHasNote.defaultValue = false

        let activityMeditationTime = NSAttributeDescription()
        activityMeditationTime.name = "meditationTime"
        activityMeditationTime.attributeType = .dateAttributeType
        activityMeditationTime.isOptional = true

        let activityNoteTime = NSAttributeDescription()
        activityNoteTime.name = "noteTime"
        activityNoteTime.attributeType = .dateAttributeType
        activityNoteTime.isOptional = true

        activityEntity.properties = [activityDate, activityHasMeditation, activityHasNote, activityMeditationTime, activityNoteTime]

        // Uniqueness constraint: one row per calendar day
        activityEntity.uniquenessConstraints = [[activityDate]]

        // ── CDStreakMeta ────────────────────────────────────────
        // Singleton entity: stores streak counters as a single row.
        let streakEntity = NSEntityDescription()
        streakEntity.name = CDEntity.streakMeta
        streakEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let streakCurrent = NSAttributeDescription()
        streakCurrent.name = "currentStreak"
        streakCurrent.attributeType = .integer32AttributeType
        streakCurrent.isOptional = false
        streakCurrent.defaultValue = 0

        let streakLongest = NSAttributeDescription()
        streakLongest.name = "longestStreak"
        streakLongest.attributeType = .integer32AttributeType
        streakLongest.isOptional = false
        streakLongest.defaultValue = 0

        let streakLastDay = NSAttributeDescription()
        streakLastDay.name = "lastCountedDay"
        streakLastDay.attributeType = .dateAttributeType
        streakLastDay.isOptional = true

        streakEntity.properties = [streakCurrent, streakLongest, streakLastDay]

        // ── CDAIDraftSession ───────────────────────────────────
        // Persisted AI-draft aggregate for cold-start recovery.
        let aiDraftEntity = NSEntityDescription()
        aiDraftEntity.name = CDEntity.aiDraftSession
        aiDraftEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let aiDraftID = NSAttributeDescription()
        aiDraftID.name = "id"
        aiDraftID.attributeType = .UUIDAttributeType
        aiDraftID.isOptional = false

        let aiDraftNoteID = NSAttributeDescription()
        aiDraftNoteID.name = "noteID"
        aiDraftNoteID.attributeType = .UUIDAttributeType
        aiDraftNoteID.isOptional = false

        let aiDraftPrompt = NSAttributeDescription()
        aiDraftPrompt.name = "promptJSON"
        aiDraftPrompt.attributeType = .binaryDataAttributeType
        aiDraftPrompt.isOptional = false

        let aiDraftSuggestions = NSAttributeDescription()
        aiDraftSuggestions.name = "suggestionsJSON"
        aiDraftSuggestions.attributeType = .binaryDataAttributeType
        aiDraftSuggestions.isOptional = false

        let aiDraftState = NSAttributeDescription()
        aiDraftState.name = "stateRaw"
        aiDraftState.attributeType = .stringAttributeType
        aiDraftState.isOptional = false
        aiDraftState.defaultValue = ""

        let aiDraftCreatedAt = NSAttributeDescription()
        aiDraftCreatedAt.name = "createdAt"
        aiDraftCreatedAt.attributeType = .dateAttributeType
        aiDraftCreatedAt.isOptional = false
        aiDraftCreatedAt.defaultValue = Date.distantPast

        aiDraftEntity.properties = [
            aiDraftID, aiDraftNoteID, aiDraftPrompt,
            aiDraftSuggestions, aiDraftState, aiDraftCreatedAt,
        ]

        // ── CDAIDraftMetric ────────────────────────────────────
        // Append-only telemetry rows. The kind scalar allows cheap rollups
        // (per-day counts, error breakdown) without decoding every payload.
        let aiDraftMetricEntity = NSEntityDescription()
        aiDraftMetricEntity.name = CDEntity.aiDraftMetric
        aiDraftMetricEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let metricID = NSAttributeDescription()
        metricID.name = "id"
        metricID.attributeType = .UUIDAttributeType
        metricID.isOptional = false

        let metricKind = NSAttributeDescription()
        metricKind.name = "kind"
        metricKind.attributeType = .stringAttributeType
        metricKind.isOptional = false
        metricKind.defaultValue = ""

        let metricPayload = NSAttributeDescription()
        metricPayload.name = "payloadJSON"
        metricPayload.attributeType = .binaryDataAttributeType
        metricPayload.isOptional = false

        let metricRecordedAt = NSAttributeDescription()
        metricRecordedAt.name = "recordedAt"
        metricRecordedAt.attributeType = .dateAttributeType
        metricRecordedAt.isOptional = false
        metricRecordedAt.defaultValue = Date.distantPast

        aiDraftMetricEntity.properties = [metricID, metricKind, metricPayload, metricRecordedAt]

        // ── Register ─────────────────────────────────────────────
        model.entities = [
            noteEntity, sessionEntity, activityEntity, streakEntity,
            aiDraftEntity, aiDraftMetricEntity,
        ]

        return model
    }
}
