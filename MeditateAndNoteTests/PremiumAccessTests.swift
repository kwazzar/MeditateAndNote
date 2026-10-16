//
//  PremiumAccessTests.swift
//  MeditateAndNoteTests
//
//  Gates for the paid surfaces: binary `PremiumFeature` mapping, the
//  `MainTheme`/`BreathingAnimationStyle` premium splits, the free AI-draft
//  quota policy, and the manager-level enforcement (theme/animation clamp,
//  draft quota burn, insights skip).
//

import XCTest
@testable import MeditateAndNote
import MeditateAndNoteCore

@MainActor
final class PremiumAccessTests: XCTestCase {

    /// Configurable `EntitlementProviding` double.
    private final class MockEntitlements: EntitlementProviding {
        var premium = false
        var status: SubscriptionStatus {
            premium
                ? SubscriptionStatus(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "premium_lifetime")
                : .none
        }
        func isActive(_ entitlement: Entitlement) -> Bool {
            premium && entitlement == .pro
        }
    }

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        await MainActor.run {
            suiteName = "PremiumAccessTests_\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suiteName)!
        }
        try await super.setUp()
    }

    override func tearDown() async throws {
        await MainActor.run {
            defaults.removePersistentDomain(forName: suiteName)
            defaults = nil
            suiteName = nil
        }
        try await super.setUp()
    }

    // MARK: - PremiumFeature mapping

    func testEveryPremiumFeatureRequiresPro() {
        for feature in PremiumFeature.allCases {
            XCTAssertEqual(feature.requiredEntitlement, .pro)
        }
    }

    func testCanAccessFollowsEntitlement() {
        let entitlements = MockEntitlements()
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(entitlements.canAccess(feature))
        }
        entitlements.premium = true
        for feature in PremiumFeature.allCases {
            XCTAssertTrue(entitlements.canAccess(feature))
        }
    }

    // MARK: - Premium splits

    func testThemePremiumSplit() {
        XCTAssertTrue(MainTheme.liquidGlass.isPremium)
        XCTAssertTrue(MainTheme.softDawn.isPremium)
        XCTAssertTrue(MainTheme.obsidian.isPremium)
        XCTAssertFalse(MainTheme.darkZen.isPremium)
        XCTAssertFalse(MainTheme.breathing.isPremium)
    }

    func testAnimationPremiumSplit() {
        XCTAssertTrue(BreathingAnimationStyle.rings.isPremium)
        XCTAssertFalse(BreathingAnimationStyle.path.isPremium)
    }

    // MARK: - ThemeManager gating

    func testThemeSelect_lockedThemeRefused() {
        let entitlements = MockEntitlements()
        let manager = ThemeManager(entitlements: entitlements, defaults: defaults)

        manager.select(.obsidian)

        XCTAssertEqual(manager.current, .darkZen)
    }

    func testThemeSelect_freeThemeAllowed() {
        let entitlements = MockEntitlements()
        let manager = ThemeManager(entitlements: entitlements, defaults: defaults)

        manager.select(.breathing)

        XCTAssertEqual(manager.current, .breathing)
    }

    func testThemeSelect_premiumThemeAllowedWhenEntitled() {
        let entitlements = MockEntitlements()
        entitlements.premium = true
        let manager = ThemeManager(entitlements: entitlements, defaults: defaults)

        manager.select(.obsidian)

        XCTAssertEqual(manager.current, .obsidian)
    }

    func testThemeInit_persistedPremiumThemeClampsToFreeWhenNotEntitled() {
        // ThemeManager.storageKey is private; the literal matches production.
        defaults.set(MainTheme.obsidian.rawValue, forKey: "selectedMainTheme")

        let manager = ThemeManager(entitlements: MockEntitlements(), defaults: defaults)

        XCTAssertEqual(manager.current, .darkZen)
    }

    func testThemeInit_persistedPremiumThemeKeptWhenEntitled() {
        defaults.set(MainTheme.obsidian.rawValue, forKey: "selectedMainTheme")

        let entitlements = MockEntitlements()
        entitlements.premium = true
        let manager = ThemeManager(entitlements: entitlements, defaults: defaults)

        XCTAssertEqual(manager.current, .obsidian)
    }

    // MARK: - AnimationSettings gating

    func testAnimationSelect_lockedStyleRefused() {
        let entitlements = MockEntitlements()
        let settings = AnimationSettings(entitlements: entitlements, defaults: defaults)

        settings.select(.rings)

        XCTAssertEqual(settings.style, .path)
    }

    func testAnimationSelect_premiumStyleAllowedWhenEntitled() {
        let entitlements = MockEntitlements()
        entitlements.premium = true
        let settings = AnimationSettings(entitlements: entitlements, defaults: defaults)

        settings.select(.rings)

        XCTAssertEqual(settings.style, .rings)
    }

    func testAnimationAttachEntitlements_clampsPersistedPremiumStyle() {
        defaults.set(BreathingAnimationStyle.rings.rawValue, forKey: AnimationSettings.storageKey)
        let settings = AnimationSettings(defaults: defaults)
        XCTAssertEqual(settings.style, .rings) // no provider attached yet

        settings.attachEntitlements(MockEntitlements())

        XCTAssertEqual(settings.style, .path)
    }

    // MARK: - AIDraftQuota policy

    func testQuota_freeUserWithinLimitAllowed() {
        XCTAssertTrue(AIDraftQuota.allowsDraft(isPremium: false, used: AIDraftQuota.freeLimit - 1))
    }

    func testQuota_freeUserAtLimitBlocked() {
        XCTAssertFalse(AIDraftQuota.allowsDraft(isPremium: false, used: AIDraftQuota.freeLimit))
    }

    func testQuota_premiumUnlimited() {
        XCTAssertTrue(AIDraftQuota.allowsDraft(isPremium: true, used: AIDraftQuota.freeLimit * 10))
    }

    // MARK: - AIDraftManager quota enforcement

    private func makeDraftService() -> StubAIDraftService {
        StubAIDraftService(
            available: true,
            nextResult: .success([AISuggestion(text: "idea", rationale: "r")])
        )
    }

    func testDraftManager_freeUserBurnsQuotaPerSuccessfulGeneration() async throws {
        let quota = InMemoryAIDraftQuotaStore()
        let manager = AIDraftManager(
            service: makeDraftService(),
            store: InMemoryAIDraftSessionStore(),
            eventBus: DomainEventBus(),
            isEntitled: { false },
            quota: quota
        )

        for _ in 0..<AIDraftQuota.freeLimit {
            _ = try await manager.startDraft(noteID: NoteID(), instructions: "i", context: NoteContent("c"))
        }
        XCTAssertEqual(quota.used(), AIDraftQuota.freeLimit)

        do {
            _ = try await manager.startDraft(noteID: NoteID(), instructions: "i", context: NoteContent("c"))
            XCTFail("Expected freeQuotaExhausted")
        } catch let error as AIDraftError {
            XCTAssertEqual(error, .freeQuotaExhausted)
        }
        XCTAssertEqual(quota.used(), AIDraftQuota.freeLimit)
    }

    func testDraftManager_failedGenerationDoesNotBurnQuota() async throws {
        let quota = InMemoryAIDraftQuotaStore()
        let failing = StubAIDraftService(available: true, nextResult: .failure(.emptyResponse))
        let manager = AIDraftManager(
            service: failing,
            store: InMemoryAIDraftSessionStore(),
            eventBus: DomainEventBus(),
            isEntitled: { false },
            quota: quota
        )

        do {
            _ = try await manager.startDraft(noteID: NoteID(), instructions: "i", context: NoteContent("c"))
            XCTFail("Expected failure")
        } catch let error as AIDraftError {
            XCTAssertEqual(error, .emptyResponse)
        }

        XCTAssertEqual(quota.used(), 0)
    }

    func testDraftManager_premiumNeverBlocked() async throws {
        let quota = InMemoryAIDraftQuotaStore(used: AIDraftQuota.freeLimit * 10)
        let manager = AIDraftManager(
            service: makeDraftService(),
            store: InMemoryAIDraftSessionStore(),
            eventBus: DomainEventBus(),
            isEntitled: { true },
            quota: quota
        )

        let session = try await manager.startDraft(noteID: NoteID(), instructions: "i", context: NoteContent("c"))

        XCTAssertEqual(session.state, .ready)
        XCTAssertEqual(quota.used(), AIDraftQuota.freeLimit * 10) // premium never records
    }

    // MARK: - NoteInsightManager gating

    func testInsightManager_unentitledSkipsAnalysis() async throws {
        let store = InMemoryNoteInsightStore()
        let bus = DomainEventBus()
        let flag = AtomicFlag()
        let analyzer = CountingAnalyzer { flag.set() }
        let manager = NoteInsightManager(
            analyzer: analyzer,
            store: store,
            notesProvider: { [Note(title: "T", content: NoteContent("calm meditation"))] },
            eventBus: bus,
            debounceInterval: 0,
            minInterval: 0,
            isEntitled: { false }
        )

        await manager.refresh(notes: [Note(title: "T", content: NoteContent("calm meditation"))])

        XCTAssertFalse(flag.isSet)
        let saved = try await store.fetchAll()
        XCTAssertTrue(saved.isEmpty)
    }

    func testInsightManager_entitledRunsAnalysis() async throws {
        let store = InMemoryNoteInsightStore()
        let bus = DomainEventBus()
        let flag = AtomicFlag()
        let analyzer = CountingAnalyzer { flag.set() }
        let note = Note(title: "T", content: NoteContent("calm meditation"))
        let manager = NoteInsightManager(
            analyzer: analyzer,
            store: store,
            notesProvider: { [note] },
            eventBus: bus,
            debounceInterval: 0,
            minInterval: 0,
            isEntitled: { true }
        )

        await manager.refresh(notes: [note])

        XCTAssertTrue(flag.isSet)
    }
}

// MARK: - Local stubs

private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock(); defer { lock.unlock() }
        value = true
    }
}

// MARK: - Local stubs

private struct StubAIDraftService: AIDraftService {
    var available: Bool
    var nextResult: Result<[AISuggestion], AIDraftError>

    var isAvailable: Bool { get async { available } }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        try nextResult.get()
    }
}

private struct CountingAnalyzer: NoteAnalyzer {
    let onAnalyze: @Sendable () -> Void

    var isAvailable: Bool { true }

    func suggestFallback(for notes: [Note]) -> [NoteInsight] {
        notes.map { NoteInsight(noteID: $0.id, summary: "summary") }
    }

    func analyze(notes: [Note]) async throws -> [NoteInsight] {
        onAnalyze()
        return suggestFallback(for: notes)
    }
}
