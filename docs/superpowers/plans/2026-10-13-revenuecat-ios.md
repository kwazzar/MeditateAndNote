# RevenueCat iOS Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add RevenueCat-backed subscriptions to the iOS app: one `pro` entitlement, a custom paywall, and a single injected `isPremium` gate — built in the project's DDD layering so Android can mirror it later.

**Architecture:** Domain entitlement types live in `MeditateAndNoteCore` (no RevenueCat/SwiftUI). A single `SubscriptionManager` (`@MainActor @Observable`) implements `SubscriptionProvidable` + `SubscriptionManageable`, consuming a `SubscriptionManaging` service (the RevenueCat adapter, an `actor`) and a `SubscriptionCache`. RevenueCat is linked to the app target only. All RevenueCat types are mapped to domain value objects inside the adapter.

**Tech Stack:** Swift 6, SwiftUI, Observation (`@Observable`), CoreData/UserDefaults, RevenueCat `purchases-ios` v5 (SPM), XCTest.

**Spec:** `docs/superpowers/specs/2026-10-13-revenuecat-ios-design.md`

## Global Constraints

- Deployment target iOS 17.6; Swift 6 language mode (strict concurrency).
- RevenueCat `purchases-ios` v5 via SPM (`https://github.com/RevenueCat/purchases-ios-spm.git`), product `RevenueCat`, linked to the **app target only**.
- `MeditateAndNoteCore` must not import `RevenueCat`, `SwiftUI`, `CoreData`, `UIKit`.
- Entitlement identifier: `"pro"`. Anonymous app user id (no login).
- No App Store Connect products in this phase; identifiers are configuration.
- RevenueCat public SDK key is not a secret (RevenueCat ships it in the app) → lives as a `Config` constant, not a committed `.xcconfig`.
- RevenueCat is the only source that may grant `pro`; the local cache is UX-only and must never extend access.
- Tests never import RevenueCat; drive protocol mocks.

## Review Focus

Inputs/conditions the spec implies but no single happy-path test covers (each gets its test in the named task):

1. **Forged/corrupted local cache** — a tampered or unreadable `UserDefaults` blob must degrade to free, never crash, never grant `pro`. (Task 4, Task 5)
2. **Device clock moved** — an entitlement with a past/future `expirationDate` must be judged by RevenueCat's reported active flag, not local time. (Task 5)
3. **RevenueCat unconfigured / empty API key** — paywall must fail gracefully, no crash, and `isPremium` must stay false even if the cache says otherwise. (Task 5)
4. **Offline during refresh/purchase** — keep last-known state, surface an error, never assert premium optimistically. (Task 5, Task 9)
5. **User cancels a purchase** — no error alert spam; status unchanged. (Task 5, Task 8, Task 9)

---

### Task 1: Link the RevenueCat SDK

**Files:**
- Modify: `MeditateAndNote.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: nothing.
- Produces: `import RevenueCat` compiles in the app target.

- [ ] **Step 1: Add the SPM dependency to the project file**

Add these objects (use the exact 24-hex ids shown so the edits are unambiguous).

In the `PBXBuildFile` section:
```
		RC0000102026101300000001 /* RevenueCat in Frameworks */ = {isa = PBXBuildFile; productRef = RC0000102026101300000002 /* RevenueCat */; };
```
In the app target's `PBXFrameworksBuildPhase` (`E36187682D68B221000E326D`), add to `files = (`:
```
				RC0000102026101300000001 /* RevenueCat in Frameworks */,
```
In the `E361876A2D68B221000E326D /* MeditateAndNote */` target, add to `packageProductDependencies = (`:
```
				RC0000102026101300000002 /* RevenueCat */,
```
In the `PBXProject` `packageReferences = (`:
```
				RC0000102026101300000003 /* XCRemoteSwiftPackageReference "purchases-ios-spm" */,
```
In the `XCLocalSwiftPackageReference` area, add:
```
		RC0000102026101300000003 /* XCRemoteSwiftPackageReference "purchases-ios-spm" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/RevenueCat/purchases-ios-spm.git";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = 5.0.0;
			};
		};
```
Near the existing `XCSwiftPackageProductDependency` object (line ~1388), add:
```
		RC0000102026101300000002 /* RevenueCat */ = {
			isa = XCSwiftPackageProductDependency;
			package = RC0000102026101300000003 /* XCRemoteSwiftPackageReference "purchases-ios-spm" */;
			productName = RevenueCat;
		};
```

Alternative if the edit is awkward: open the project in Xcode and use File → Add Package Dependencies with the same URL, product `RevenueCat`.

- [ ] **Step 2: Resolve packages and confirm it builds**

Run: `xcodebuild -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'generic/platform=iOS Simulator' build`
Expected: BUILD SUCCEEDED (package resolves; no `import RevenueCat` code yet).

- [ ] **Step 3: Commit**

```bash
git add MeditateAndNote.xcodeproj/project.pbxproj
git commit -m "build: add RevenueCat SPM dependency (app target only)"
```

---

### Task 2: Domain types

**Files:**
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/Entitlement.swift`
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionStatus.swift`
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionOffering.swift`
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionManaging.swift`
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionOperationError.swift`
- Create: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/SubscriptionCache.swift`
- Test: `MeditateAndNoteTests/SubscriptionStatusTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `Entitlement`, `SubscriptionStatus` (with `.none`, `isActive(_:)`), `SubscriptionOffering`, `SubscriptionPackage`, `EntitlementProviding`, `SubscriptionManaging`, `SubscriptionProvidable`, `SubscriptionManageable`, `SubscriptionOperationError`, `SubscriptionCache`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import MeditateAndNoteCore

final class SubscriptionStatusTests: XCTestCase {
    func test_isActive_trueOnlyForPresentEntitlement() {
        let status = SubscriptionStatus(
            activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p"
        )
        XCTAssertTrue(status.isActive(.pro))
    }

    func test_isActive_falseWhenAbsent() {
        XCTAssertFalse(SubscriptionStatus.none.isActive(.pro))
    }

    func test_none_isInactive() {
        XCTAssertEqual(SubscriptionStatus.none.activeEntitlements, [])
        XCTAssertFalse(SubscriptionStatus.none.willRenew)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/SubscriptionStatusTests`
Expected: FAIL — `SubscriptionStatus` not defined.

- [ ] **Step 3: Implement the types**

`Entitlement.swift`:
```swift
public enum Entitlement: String, Sendable, CaseIterable {
    case pro
}
```
`SubscriptionStatus.swift`:
```swift
public struct SubscriptionStatus: Sendable, Equatable {
    public let activeEntitlements: Set<Entitlement>
    public let expirationDate: Date?
    public let willRenew: Bool
    public let productIdentifier: String?

    public static let none = SubscriptionStatus(
        activeEntitlements: [], expirationDate: nil, willRenew: false, productIdentifier: nil
    )

    public init(
        activeEntitlements: Set<Entitlement>,
        expirationDate: Date?,
        willRenew: Bool,
        productIdentifier: String?
    ) {
        self.activeEntitlements = activeEntitlements
        self.expirationDate = expirationDate
        self.willRenew = willRenew
        self.productIdentifier = productIdentifier
    }

    public func isActive(_ entitlement: Entitlement) -> Bool {
        activeEntitlements.contains(entitlement)
    }
}
```
`SubscriptionOffering.swift`:
```swift
public struct SubscriptionPackage: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let priceString: String
    public init(id: String, title: String, priceString: String) { ... }
}

public struct SubscriptionOffering: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let packages: [SubscriptionPackage]
    public init(id: String, title: String, packages: [SubscriptionPackage]) { ... }
}
```
`SubscriptionManaging.swift`:
```swift
public protocol EntitlementProviding {
    var status: SubscriptionStatus { get }
    func isActive(_ entitlement: Entitlement) -> Bool
}

public protocol SubscriptionManaging: Sendable {
    var isConfigured: Bool { get }
    func offerings() async throws -> [SubscriptionOffering]
    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus
    func restore() async throws -> SubscriptionStatus
    func refresh() async -> SubscriptionStatus
}

public protocol SubscriptionProvidable: EntitlementProviding {}
public protocol SubscriptionManageable: SubscriptionManaging {}
```
`SubscriptionOperationError.swift`:
```swift
public enum SubscriptionOperationError: Error, Equatable {
    case notConfigured
    case loadFailed
    case purchaseFailed
    case restoreFailed
    case cancelled
}
```
`SubscriptionCache.swift`:
```swift
public protocol SubscriptionCache: Sendable {
    func load() -> SubscriptionStatus?
    func save(_ status: SubscriptionStatus)
}
```
Fill in the `init` bodies for the two offering types.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/SubscriptionStatusTests`
Expected: PASS.

- [ ] **Step 5: Verify the Domain layer stays clean**

Run: `grep -rn "import RevenueCat\|import SwiftUI\|import CoreData\|import UIKit" Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions MeditateAndNoteTests/SubscriptionStatusTests.swift
git commit -m "feat(domain): add subscription entitlement types"
```

---

### Task 3: `DomainEvent.subscriptionChanged` + update all exhaustive switches

**Files:**
- Modify: `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Events/DomainEvents.swift:14-22`
- Modify (add `.subscriptionChanged` to the ignore branch of each switch):
  `MeditateAndNote/AppContainer/AIDraftScope.swift:23,32`,
  `MeditateAndNote/AppContainer/SearchScope.swift:21,30`,
  `MeditateAndNote/AppContainer/NoteScope.swift:24,33`,
  `MeditateAndNote/AppContainer/StreakScope.swift:19,28`,
  `MeditateAndNote/AppContainer/MeditationScope.swift:21,30`,
  `MeditateAndNote/Persistence/CoreDataSessionStore.swift:106`,
  `MeditateAndNote/ViewModels/MeditationViewModel.swift:202`,
  `MeditateAndNote/Services/Streak/StreakTracker.swift:261`,
  `MeditateAndNote/Services/AI/NoteInsightManager.swift:142`,
  `MeditateAndNote/ViewModels/NoteInsightsViewModel.swift:101`,
  `MeditateAndNote/ViewModels/NoteMenuViewModel.swift:89`,
  `Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Streak/StreakInsightManager.swift:127`
- Test: `MeditateAndNoteTests/EventRoutingTableTests.swift` (modify if it enumerates cases)

**Interfaces:**
- Consumes: `SubscriptionStatus` (Task 2).
- Produces: `DomainEvent.subscriptionChanged(SubscriptionStatus)`, consumed by Task 5.

- [ ] **Step 1: Write the failing test**

Add to `EventRoutingTableTests.swift` (a test asserting the new event is recognized by the routing table without crashing and is not claimed by any scope):
```swift
func test_subscriptionChanged_isUnhandledByAllScopes() {
    let event = DomainEvent.subscriptionChanged(.none)
    XCTAssertFalse(StreakScope.handles(event))
    XCTAssertFalse(NoteScope.handles(event))
    XCTAssertFalse(AIDraftScope.handles(event))
    XCTAssertFalse(MeditationScope.handles(event))
    XCTAssertFalse(SearchScope.handles(event))
}
```
(`@testable import MeditateAndNote` if the file does not already.)

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/EventRoutingTableTests`
Expected: FAIL — no case `subscriptionChanged`.

- [ ] **Step 3: Add the case and update every switch**

In `DomainEvents.swift` add to the enum:
```swift
case subscriptionChanged(SubscriptionStatus)
```
Then, in each switch listed under Files, add `.subscriptionChanged` to the branch that ignores the event (the existing `default`-style / "no-op" case, e.g. alongside `.noteInsightsUpdated`). In `handles(_:)`, add `.subscriptionChanged` to the branch returning `false`. The switch is exhaustive, so the compiler will flag any file you miss — fix all of them.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/EventRoutingTableTests`
Expected: PASS, and the whole target compiles.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(domain): add DomainEvent.subscriptionChanged and update routing switches"
```

---

### Task 4: `UserDefaultsSubscriptionCache`

**Files:**
- Create: `MeditateAndNote/Persistence/UserDefaultsSubscriptionCache.swift`
- Test: `MeditateAndNoteTests/UserDefaultsSubscriptionCacheTests.swift`

**Interfaces:**
- Consumes: `SubscriptionCache`, `SubscriptionStatus` (Task 2).
- Produces: `UserDefaultsSubscriptionCache: SubscriptionCache`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

final class UserDefaultsSubscriptionCacheTests: XCTestCase {
    private func makeCache() -> (UserDefaultsSubscriptionCache, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        return (UserDefaultsSubscriptionCache(defaults: defaults), defaults)
    }

    func test_roundTrip() {
        let (cache, _) = makeCache()
        let status = SubscriptionStatus(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
        cache.save(status)
        XCTAssertEqual(cache.load(), status)
    }

    func test_emptyReturnsNil() {
        let (cache, _) = makeCache()
        XCTAssertNil(cache.load())
    }

    func test_corruptedBlobReturnsNilNotCrash() {
        let (cache, defaults) = makeCache()
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "subscription.status.v1")
        XCTAssertNil(cache.load())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/UserDefaultsSubscriptionCacheTests`
Expected: FAIL — type not defined.

- [ ] **Step 3: Implement**

`UserDefaultsSubscriptionCache` stores `SubscriptionStatus` as JSON under key `"subscription.status.v1"`. Make `SubscriptionStatus` `Codable` (add `Codable` conformance in Task 2's file). `load()` decodes and returns `nil` on any decode failure (never throws, never crashes). `save()` encodes and writes; ignores encode failure.

- [ ] **Step 4: Run test to verify it passes**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MeditateAndNote/Persistence/UserDefaultsSubscriptionCache.swift MeditateAndNoteTests/UserDefaultsSubscriptionCacheTests.swift
git commit -m "feat(infra): add UserDefaults subscription cache"
```

---

### Task 5: `SubscriptionManager`

**Files:**
- Create: `MeditateAndNote/Services/Subscriptions/SubscriptionManager.swift`
- Test: `MeditateAndNoteTests/SubscriptionManagerTests.swift`
- Test: `MeditateAndNoteTests/SubscriptionTrustBoundaryTests.swift`

**Interfaces:**
- Consumes: `SubscriptionProvidable`, `SubscriptionManageable`, `SubscriptionManaging`, `SubscriptionCache`, `DomainEvent` (Tasks 2–4).
- Produces: `@MainActor @Observable final class SubscriptionManager` with `status`, `isPremium`, `refresh()`, `offerings()`, `purchase(_:)`, `restore()`; publishes `.subscriptionChanged` on `DomainEventBus`.

- [ ] **Step 1: Write the failing tests**

`SubscriptionManagerTests.swift` (mock service inline):
```swift
import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

private final class MockService: SubscriptionManaging, @unchecked Sendable {
    var isConfigured = true
    var nextStatus: SubscriptionStatus = .none
    var offeringsToReturn: [SubscriptionOffering] = []
    var purchaseResult: Result<SubscriptionStatus, Error> = .success(.none)
    func offerings() async throws -> [SubscriptionOffering] { offeringsToReturn }
    func purchase(_ p: SubscriptionPackage) async throws -> SubscriptionStatus {
        switch purchaseResult { case .success(let s): return s; case .failure(let e): throw e }
    }
    func restore() async throws -> SubscriptionStatus { nextStatus }
    func refresh() async -> SubscriptionStatus { nextStatus }
}

private struct MemoryCache: SubscriptionCache {
    final class Box: @unchecked Sendable { var value: SubscriptionStatus? }
    let box: Box
    init(_ value: SubscriptionStatus?) { box = Box(); box.value = value }
    func load() -> SubscriptionStatus? { box.value }
    func save(_ status: SubscriptionStatus) { box.value = status }
}

final class EventRecorder: @unchecked Sendable {
    private var events: [DomainEvent] = []
    private let lock = NSLock()
    func record(_ event: DomainEvent) { lock.lock(); events.append(event); lock.unlock() }
    func count(where predicate: (DomainEvent) -> Bool) -> Int {
        lock.lock(); defer { lock.unlock() }; return events.filter(predicate).count
    }
}

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    private func pro() -> SubscriptionStatus {
        .init(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
    }

    func test_cacheFirstThenRefreshGrants() async {
        let service = MockService(); service.nextStatus = pro()
        let cache = MemoryCache(pro())
        let bus = DomainEventBus()
        let manager = SubscriptionManager(service: service, cache: cache, eventBus: bus)
        XCTAssertTrue(manager.isPremium)                 // cache-first
        let changed = await manager.refresh()
        XCTAssertTrue(changed.isActive(.pro))
        XCTAssertEqual(cache.box.value, pro())           // cache overwritten by RC result
    }

    func test_refreshDowngradePublishesEvent() async {
        let service = MockService(); service.nextStatus = .none
        let cache = MemoryCache(pro())
        let bus = DomainEventBus()
        let recorder = EventRecorder()                 // @unchecked Sendable box, see below
        let token = bus.subscribe { recorder.record($0) }
        let manager = SubscriptionManager(service: service, cache: cache, eventBus: bus)
        _ = await manager.refresh()
        bus.unsubscribe(token)
        XCTAssertFalse(manager.isPremium)
        XCTAssertEqual(recorder.count { if case .subscriptionChanged = $0 { true } else { false } }, 1)
    }

    func test_cancelledPurchaseLeavesStatusUnchanged() async {
        let service = MockService()
        service.purchaseResult = .failure(SubscriptionOperationError.cancelled)
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        do { _ = try await manager.purchase(SubscriptionPackage(id: "p", title: "t", priceString: "$1")) }
        catch let error as SubscriptionOperationError { XCTAssertEqual(error, .cancelled) }
        XCTAssertFalse(manager.isPremium)
    }
}
```

`SubscriptionTrustBoundaryTests.swift`:
```swift
import XCTest
import MeditateAndNoteCore
@testable import MeditateAndNote

@MainActor
final class SubscriptionTrustBoundaryTests: XCTestCase {
    private func pro() -> SubscriptionStatus {
        .init(activeEntitlements: [.pro], expirationDate: nil, willRenew: true, productIdentifier: "p")
    }

    func test_unconfiguredServiceNeverGrantsEvenWithCachedPro() async {
        let service = MockService(); service.isConfigured = false; service.nextStatus = .none
        let manager = SubscriptionManager(service: service, cache: MemoryCache(pro()), eventBus: DomainEventBus())
        XCTAssertFalse(manager.isPremium)
        _ = await manager.refresh()
        XCTAssertFalse(manager.isPremium)
    }

    func test_refreshResultWinsOverCache_noLocalClock() async {
        // RC reports inactive even though cache says active → free after refresh.
        let service = MockService(); service.nextStatus = .none
        let manager = SubscriptionManager(service: service, cache: MemoryCache(pro()), eventBus: DomainEventBus())
        _ = await manager.refresh()
        XCTAssertFalse(manager.isPremium)
    }
}
```
(Reuse `MockService`/`MemoryCache` by moving them to one shared file, e.g. `MeditateAndNoteTests/Support/SubscriptionMocks.swift`, if the second file cannot see the private ones.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/SubscriptionManagerTests -only-testing:MeditateAndNoteTests/SubscriptionTrustBoundaryTests`
Expected: FAIL — `SubscriptionManager` not defined.

- [ ] **Step 3: Implement `SubscriptionManager`**

```swift
@MainActor @Observable
final class SubscriptionManager: SubscriptionProvidable, SubscriptionManageable {
    private(set) var status: SubscriptionStatus
    private let service: any SubscriptionManaging
    private let cache: any SubscriptionCache
    private let eventBus: any DomainEventPublisher

    init(service: any SubscriptionManaging, cache: any SubscriptionCache, eventBus: any DomainEventPublisher) {
        self.service = service
        self.cache = cache
        self.eventBus = eventBus
        // UX fast-path only; RC overrides on next refresh. Unconfigured ⇒ never grant.
        self.status = service.isConfigured ? (cache.load() ?? .none) : .none
    }

    var isPremium: Bool { isActive(.pro) }
    func isActive(_ entitlement: Entitlement) -> Bool { status.isActive(entitlement) }

    @discardableResult
    func refresh() async -> SubscriptionStatus {
        let fresh = await service.refresh()
        apply(fresh)
        return fresh
    }

    func offerings() async throws -> [SubscriptionOffering] {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        return try await service.offerings()
    }

    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        do {
            let fresh = try await service.purchase(package)
            apply(fresh)
            return fresh
        } catch let error as SubscriptionOperationError {
            throw error
        } catch {
            throw SubscriptionOperationError.purchaseFailed
        }
    }

    func restore() async throws -> SubscriptionStatus {
        guard service.isConfigured else { throw SubscriptionOperationError.notConfigured }
        do {
            let fresh = try await service.restore()
            apply(fresh)
            return fresh
        } catch {
            throw SubscriptionOperationError.restoreFailed
        }
    }

    private func apply(_ fresh: SubscriptionStatus) {
        guard fresh != status else { return }
        status = fresh
        cache.save(fresh)
        eventBus.publish(.subscriptionChanged(fresh))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MeditateAndNote/Services/Subscriptions/SubscriptionManager.swift MeditateAndNoteTests/SubscriptionManagerTests.swift MeditateAndNoteTests/SubscriptionTrustBoundaryTests.swift
git commit -m "feat(app): add SubscriptionManager with trust-boundary guards"
```

---

### Task 6: `RevenueCatPurchasesService` (the only RevenueCat importer)

**Files:**
- Create: `MeditateAndNote/Services/Subscriptions/RevenueCatPurchasesService.swift`

**Interfaces:**
- Consumes: `SubscriptionManaging`, `SubscriptionStatus`, `SubscriptionOffering`, `SubscriptionPackage`, `SubscriptionOperationError` (Task 2).
- Produces: `actor RevenueCatPurchasesService: SubscriptionManaging`; static `configure(apiKey:)` that calls `Purchases.configure` once.

- [ ] **Step 1: Implement the adapter**

```swift
import Foundation
import RevenueCat
import MeditateAndNoteCore

actor RevenueCatPurchasesService: SubscriptionManaging {
    private let entitlementID: Entitlement = .pro

    nonisolated var isConfigured: Bool { Purchases.isConfigured }

    static func configure(apiKey: String) {
        guard !apiKey.isEmpty, !Purchases.isConfigured else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    func offerings() async throws -> [SubscriptionOffering] {
        do {
            let offerings = try await Purchases.shared.offerings()
            return offerings.all.values.map(Self.map)
        } catch { throw SubscriptionOperationError.loadFailed }
    }

    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus {
        guard let rcPackage = await findPackage(id: package.id) else {
            throw SubscriptionOperationError.purchaseFailed
        }
        do {
            let result = try await Purchases.shared.purchase(package: rcPackage)
            return Self.map(result.customerInfo, entitlement: entitlementID, packageID: package.id)
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError { throw SubscriptionOperationError.cancelled }
            throw SubscriptionOperationError.purchaseFailed
        } catch {
            throw SubscriptionOperationError.purchaseFailed
        }
    }

    func restore() async throws -> SubscriptionStatus {
        do {
            let info = try await Purchases.shared.restorePurchases()
            return Self.map(info, entitlement: entitlementID, packageID: nil)
        } catch { throw SubscriptionOperationError.restoreFailed }
    }

    func refresh() async -> SubscriptionStatus {
        guard isConfigured else { return .none }
        do {
            let info = try await Purchases.shared.customerInfo()
            return Self.map(info, entitlement: entitlementID, packageID: nil)
        } catch {
            return .none
        }
    }

    private func findPackage(id: String) async -> Package? {
        try? await Purchases.shared.offerings().all.values
            .flatMap(\.availablePackages)
            .first { $0.identifier == id }
    }

    // MARK: Mapping (RevenueCat → Domain)

    private static func map(_ offering: Offering) -> SubscriptionOffering {
        SubscriptionOffering(
            id: offering.identifier,
            title: offering.metadata["title"] as? String ?? offering.identifier,
            packages: offering.availablePackages.map {
                SubscriptionPackage(
                    id: $0.identifier,
                    title: $0.storeProduct.localizedTitle,
                    priceString: $0.storeProduct.localizedPriceString
                )
            }
        )
    }

    private static func map(_ info: CustomerInfo, entitlement: Entitlement, packageID: String?) -> SubscriptionStatus {
        let active = info.entitlements.active.keys.compactMap(Entitlement.init(rawValue:))
        let credited = info.entitlements.active[entitlement.rawValue]
        return SubscriptionStatus(
            activeEntitlements: Set(active),
            expirationDate: credited?.expirationDate,
            willRenew: credited?.willRenew ?? false,
            productIdentifier: packageID ?? credited?.productIdentifier
        )
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'generic/platform=iOS Simulator' build`
Expected: BUILD SUCCEEDED. If `Purchases.isConfigured` / `ErrorCode` names differ in v5, adjust to the v5 API surface (`Purchases.shared` static accessor, `ErrorCode.purchaseCancelledError`).

- [ ] **Step 3: Commit**

```bash
git add MeditateAndNote/Services/Subscriptions/RevenueCatPurchasesService.swift
git commit -m "feat(infra): add RevenueCatPurchasesService adapter"
```

---

### Task 7: DI + launch wiring

**Files:**
- Create: `MeditateAndNote/AppContainer/SubscriptionScope.swift`
- Modify: `MeditateAndNote/AppContainer/AppContainer.swift`
- Modify: `MeditateAndNote/MeditateAndNoteApp.swift`
- Modify: `MeditateAndNote/Navigation/Config.swift`

**Interfaces:**
- Consumes: `SubscriptionManager` (Task 5), `RevenueCatPurchasesService` (Task 6), `UserDefaultsSubscriptionCache` (Task 4).
- Produces: `AppContainer.makeSubscriptionViewModel()`, `AppContainer.makePaywallViewModel()`, `Config.revenueCatAPIKey`, `Config.proEntitlementID`; `SubscriptionManager` injected into the environment.

- [ ] **Step 1: Add config constants**

In `Config.swift`:
```swift
public static let revenueCatAPIKey: String = "appl_REPLACE_ME"
public static let proEntitlementID: String = "pro"
```
(RC public SDK key is safe to embed; swap `appl_REPLACE_ME` for the real test-store key.)

- [ ] **Step 2: Add the scope**

`SubscriptionScope.swift`:
```swift
import Foundation
import MeditateAndNoteCore

@MainActor
final class SubscriptionScope {
    let manager: SubscriptionManager

    init(eventBus: any DomainEventPublisher) {
        let service = RevenueCatPurchasesService()
        let cache = UserDefaultsSubscriptionCache()
        manager = SubscriptionManager(service: service, cache: cache, eventBus: eventBus)
    }
}
```

- [ ] **Step 3: Wire `AppContainer`**

Add `@MainActor private lazy var subscription = SubscriptionScope(eventBus: eventBus)` and the accessor `var subscriptionManager: SubscriptionManager { subscription.manager }`.
Do **not** add the VM factories here — they depend on `SubscriptionViewModel`/`PaywallViewModel` from Tasks 8–9 and are added in those tasks (so each task compiles on its own).

- [ ] **Step 4: Configure RevenueCat at launch and inject**

In `MeditateAndNoteApp.swift`, before `RootContainer()` is built:
```swift
init() {
    RevenueCatPurchasesService.configure(apiKey: Config.revenueCatAPIKey)
}
```
Add `.environment(container.subscriptionManager)` to the `RootContainer()` modifier chain, and expose `var subscriptionManager: SubscriptionManager { subscription.manager }` on `AppContainer`.

- [ ] **Step 5: Refresh on launch and foreground**

In `RootContainer` (or the app's `.task`), call `await container.subscriptionManager.refresh()` once on appear, and again on `ScenePhase` becoming `.active`.

- [ ] **Step 6: Build**

Run: `xcodebuild -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'generic/platform=iOS Simulator' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(app): wire SubscriptionScope, AppContainer factories, launch config"
```

---

### Task 8: `SubscriptionViewModel`

**Files:**
- Create: `MeditateAndNote/ViewModels/SubscriptionViewModel.swift`
- Test: `MeditateAndNoteTests/SubscriptionViewModelTests.swift`

**Interfaces:**
- Consumes: `SubscriptionProvidable`, `SubscriptionManageable`.
- Produces: `@MainActor @Observable final class SubscriptionViewModel` with `isPremium`, `priceText`, `errorMessage`, `isBusy`, `restore()`.

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
final class SubscriptionViewModelTests: XCTestCase {
    func test_isPremiumReflectsProvider() {
        let service = MockService(); service.isConfigured = true
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        let vm = SubscriptionViewModel(providable: manager, manageable: manager)
        XCTAssertFalse(vm.isPremium)
    }

    func test_restoreCancelledSetsNoError() async {
        // restore() success path sets isBusy false and no error
        let service = MockService(); service.nextStatus = .none
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        let vm = SubscriptionViewModel(providable: manager, manageable: manager)
        await vm.restore()
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isBusy)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/SubscriptionViewModelTests`
Expected: FAIL — type not defined.

- [ ] **Step 3: Implement**

`SubscriptionViewModel` holds `any SubscriptionProvidable` + `any SubscriptionManageable`; `isPremium` mirrors `providable.isActive(.pro)`; `restore()` sets `isBusy`, calls `manageable.restore()`, maps `SubscriptionOperationError` to `errorMessage` (`.cancelled` → no message), clears `isBusy`. Expose `refreshStatus()` to reload after external changes.

- [ ] **Step 4: Add the `AppContainer` factory**

Add to `AppContainer.swift`:
```swift
@MainActor func makeSubscriptionViewModel() -> SubscriptionViewModel {
    SubscriptionViewModel(providable: subscription.manager, manageable: subscription.manager)
}
```

- [ ] **Step 5: Run test to verify it passes**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MeditateAndNote/ViewModels/SubscriptionViewModel.swift MeditateAndNoteTests/SubscriptionViewModelTests.swift MeditateAndNote/AppContainer/AppContainer.swift
git commit -m "feat(presentation): add SubscriptionViewModel"
```

---

### Task 9: `PaywallViewModel`

**Files:**
- Create: `MeditateAndNote/ViewModels/PaywallViewModel.swift`
- Test: `MeditateAndNoteTests/PaywallViewModelTests.swift`

**Interfaces:**
- Consumes: `SubscriptionProvidable`, `SubscriptionManageable`, `SubscriptionOffering`, `SubscriptionPackage`.
- Produces: `@MainActor @Observable final class PaywallViewModel` with `packages`, `selectedPackage`, `isPremium`, `isLoading`, `errorMessage`, `load()`, `purchaseSelected()`, `restore()`.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor
final class PaywallViewModelTests: XCTestCase {
    func test_load_populatesPackages() async {
        let service = MockService(); service.isConfigured = true
        service.offeringsToReturn = [.init(id: "default", title: "Default", packages: [
            .init(id: "pro.monthly", title: "Monthly", priceString: "$4.99")
        ])]
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        await vm.load()
        XCTAssertEqual(vm.packages.map(\.id), ["pro.monthly"])
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadWhenUnconfiguredSurfacesError() async {
        let service = MockService(); service.isConfigured = false
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        await vm.load()
        XCTAssertTrue(vm.packages.isEmpty)
        XCTAssertNotNil(vm.errorMessage)      // "notConfigured"
    }

    func test_cancelPurchaseNoError() async {
        let service = MockService(); service.isConfigured = true
        service.purchaseResult = .failure(SubscriptionOperationError.cancelled)
        let manager = SubscriptionManager(service: service, cache: MemoryCache(.none), eventBus: DomainEventBus())
        let vm = PaywallViewModel(providable: manager, manageable: manager)
        vm.selectedPackage = SubscriptionPackage(id: "p", title: "t", priceString: "$1")
        await vm.purchaseSelected()
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isPremium)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MeditateAndNoteTests/PaywallViewModelTests`
Expected: FAIL — type not defined.

- [ ] **Step 3: Implement `PaywallViewModel`**

`load()` → `isLoading = true`; `try await manageable.offerings()` → flatten to `packages`, select first; on `SubscriptionOperationError.notConfigured` set a user-facing "subscriptions unavailable" message; on other errors "couldn't load". `purchaseSelected()` guards a selected package, `isLoading` around `manageable.purchase`, updates `isPremium` from `providable`, `.cancelled` → silent. `restore()` maps errors like Task 8.

- [ ] **Step 4: Add the `AppContainer` factory**

Add to `AppContainer.swift`:
```swift
@MainActor func makePaywallViewModel() -> PaywallViewModel {
    PaywallViewModel(providable: subscription.manager, manageable: subscription.manager)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run the command from Step 2. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MeditateAndNote/ViewModels/PaywallViewModel.swift MeditateAndNoteTests/PaywallViewModelTests.swift MeditateAndNote/AppContainer/AppContainer.swift
git commit -m "feat(presentation): add PaywallViewModel"
```

---

### Task 10: Paywall view + Settings entry

**Files:**
- Create: `MeditateAndNote/Views/Paywall/PaywallView.swift`
- Create: `MeditateAndNote/Views/Settings/SubscriptionSection.swift`
- Modify: `MeditateAndNote/Views/Settings/SettingsView.swift:36-42` (insert section)

**Interfaces:**
- Consumes: `PaywallViewModel` (Task 9), `SubscriptionViewModel` (Task 8), `AppContainer` factories (Task 7).
- Produces: user-visible paywall + "Upgrade / Pro" Settings row.

- [ ] **Step 1: Build `PaywallView`**

Custom SwiftUI, `ThemeManager`-styled. Shows `viewModel.packages` with `priceString`, a Subscribe button (calls `purchaseSelected()`), Restore button, loading spinner, error text, and legal links (Terms/Privacy static URLs). Load via `.task { await viewModel.load() }`. Dismiss on `isPremium`.

- [ ] **Step 2: Add the Settings entry**

`SubscriptionSection.swift`: a row showing "Upgrade to Pro" when `!viewModel.isPremium` (tap → present `PaywallView` via `@State showPaywall`) or "Pro active" when premium. `SettingsView` adds `SubscriptionSection(...)` to the `VStack` and passes `container: container`.

- [ ] **Step 3: Build and run**

Run: `xcodebuild -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke on simulator**

Launch via the MCP `build_run_sim`, open Settings → confirm the Upgrade row and that the paywall presents, shows packages (or the "unavailable" state with `appl_REPLACE_ME`), and Restore runs without crashing.

- [ ] **Step 5: Commit**

```bash
git add MeditateAndNote/Views/Paywall MeditateAndNote/Views/Settings
git commit -m "feat(presentation): add paywall view and Settings upgrade entry"
```

---

## Final verification (after all tasks)

- [ ] Full test suite green: `xcodebuild test -project MeditateAndNote.xcodeproj -scheme MeditateAndNote -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] `grep -rn "import RevenueCat" Packages/MeditateAndNoteCore/Sources` → no output (Domain stays clean).
- [ ] `grep -rn "import RevenueCat" MeditateAndNote` → only `RevenueCatPurchasesService.swift`.
- [ ] ViewModels reference `SubscriptionProvidable`/`SubscriptionManageable`, never `SubscriptionManager` or `Purchases` directly.
- [ ] Android follow-up noted in the spec is untouched.
