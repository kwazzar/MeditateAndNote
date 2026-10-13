# RevenueCat iOS Integration — Design

Date: 2026-10-13
Status: Approved design, pending implementation plan
Worktree: `/Users/nazar/Swift/revenuecat` (branch `revenuecat`, based on `main`)

## Goal

Add in-app subscriptions to the iOS app using RevenueCat, following the project's
DDD layering. Ship the entitlement plumbing and a single paid entitlement
(`pro`) now; the *exact* set of features gated behind it is decided later.

## Non-goals

- No App Store Connect product/store setup in this phase. Integration is
  config-driven and testable via RevenueCat's Test Store.
- No Android implementation now. The Domain types are shaped so a future
  Kotlin `purchases-android` adapter can mirror them (same entitlement id).
- No social/account system. RevenueCat uses an anonymous app user id.

## Requirements

- One paid entitlement, identifier `pro`.
- A custom SwiftUI paywall (not RevenueCat-hosted Paywalls), styled by `ThemeManager`.
- Reachable from a Settings "Upgrade / Pro" row, plus the ability to present it
  contextually when a gated feature is tapped.
- A single injected source of truth for entitlement state (`isPremium`).
- Works offline using a cached last-known status; RevenueCat is the source of truth.
- Restore purchases supported.
- Testable without the RevenueCat SDK (mock provider/managing protocols).
- RC public SDK key and product ids are configuration, not hard-coded.

## Architecture (layers, dependencies point inward)

```
Presentation   PaywallView, SubscriptionViewModel, PaywallViewModel, Settings subscription row
      ↓
Application    SubscriptionManager (: SubscriptionProvidable, SubscriptionManageable)
      ↓
Domain         Entitlement, SubscriptionStatus, SubscriptionOffering/Package,
(Core pkg)     EntitlementProviding, SubscriptionManaging, SubscriptionOperationError,
               SubscriptionCache protocol, DomainEvent.subscriptionChanged
      ↑
Infrastructure RevenueCatPurchasesService (only file importing RevenueCat),
               UserDefaultsSubscriptionCache
```

Hard rules preserved:
- Domain never imports `RevenueCat`, `SwiftUI`, `CoreData`.
- RevenueCat types (`CustomerInfo`, `Offering`, `Package`) are mapped to Domain
  value objects inside `RevenueCatPurchasesService` only.
- ViewModels depend on `SubscriptionProvidable` / `SubscriptionManageable`,
  never on `SubscriptionManager` or RevenueCat.

## Domain (`Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore/Subscriptions/`)

- `Entitlement.swift`
  ```swift
  public enum Entitlement: String, Sendable, CaseIterable {
      case pro
  }
  ```
- `SubscriptionStatus.swift` — value object:
  `activeEntitlements: Set<Entitlement>`, `expirationDate: Date?`,
  `willRenew: Bool`, `productIdentifier: String?`,
  `func isActive(_ entitlement: Entitlement) -> Bool`, `static let none`.
- `SubscriptionOffering.swift` — `SubscriptionOffering` (id, title,
  `packages: [SubscriptionPackage]`) and `SubscriptionPackage`
  (id, `title`, `priceString`). Decouples UI from RC `Offering`/`Package`.
- `EntitlementProviding.swift` — read:
  `var status: SubscriptionStatus { get }`,
  `func isActive(_ entitlement: Entitlement) -> Bool`.
- `SubscriptionManaging.swift` — write:
  `func offerings() async throws -> [SubscriptionOffering]`,
  `func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus`,
  `func restore() async throws -> SubscriptionStatus`,
  `func refresh() async -> SubscriptionStatus`.
- `SubscriptionOperationError.swift` — `loadFailed`, `purchaseFailed`,
  `restoreFailed`, `cancelled` (matches `NoteOperationError` convention).
- `SubscriptionCache.swift` — `load() -> SubscriptionStatus?`,
  `save(_ status: SubscriptionStatus)`.
- Edit `Events/DomainEvents.swift`: add
  `case subscriptionChanged(SubscriptionStatus)`. This is a closed sum type, so
  every `DomainEventRouting.handles` implementation and `EventLoopCoordinator`
  must be updated (compile-time enforced).

## Infrastructure

- `MeditateAndNote/Services/Subscriptions/RevenueCatPurchasesService.swift` —
  conforms to `EntitlementProviding` + `SubscriptionManaging`. The ONLY file that
  imports `RevenueCat`. Maps `CustomerInfo.entitlements` → `Set<Entitlement>`,
  `Offering`/`Package` → Domain VOs. RC v5 is not Sendable → wrap calls with
  appropriate isolation inside this adapter.
- `MeditateAndNote/Persistence/UserDefaultsSubscriptionCache.swift` —
  implements `SubscriptionCache` for last-known status (offline launch).

## Application

- `MeditateAndNote/Services/Subscriptions/SubscriptionManager.swift` —
  implements `SubscriptionProvidable` + `SubscriptionManageable`. Owns the RC
  service + cache. Loads cached status immediately, then async refresh on launch
  and on foreground. On any status change: persist to cache, publish
  `.subscriptionChanged`. Exposes `isPremium` (`isActive(.pro)`).

## DI + launch

- `MeditateAndNote/AppContainer/SubscriptionScope.swift` — builds cache +
  RC service + manager.
- Edit `AppContainer.swift` — add `subscription` scope, `makeSubscriptionViewModel()`,
  `makePaywallViewModel()`.
- Edit `MeditateAndNote/MeditateAndNoteApp.swift` — `Purchases.configure(withAPIKey:)`
  once at launch (before any RC call); inject `SubscriptionManager` via
  `.environment(...)`.

## Presentation

- `ViewModels/SubscriptionViewModel.swift` (`@Observable`) — exposes `isPremium`,
  display price(s), `purchase()`, `restore()`, error state; drives the Settings row.
- `ViewModels/PaywallViewModel.swift` (`@Observable`) — loads offerings, exposes
  packages/prices, buy/restore, loading/error states.
- `Views/Paywall/PaywallView.swift` — custom SwiftUI, `ThemeManager`-styled,
  shows offering/price, Subscribe button, Restore, legal links. Presented as a
  sheet/full-screen cover.
- `Views/Settings/SubscriptionSection.swift` — "Upgrade / Pro" row (or "Pro
  active"), wired into `SettingsView`.
- Gate helper: views read `isPremium` from the injected manager; tapping a gated
  feature sets a flag that presents `PaywallView`. No feature is mapped to the
  gate yet beyond the plumbing.

## Configuration

- Add `purchases-ios` (RevenueCat, v5) as an SPM dependency to the **app target
  only** in `MeditateAndNote.xcodeproj`. `MeditateAndNoteCore` stays SDK-free.
- `Config.revenueCatAPIKey` reads `REVENUECAT_API_KEY` from `Info.plist`,
  defaulted from a gitignored `.xcconfig` so no secret is committed.
- Entitlement/product identifiers are constants in one place (config), not
  scattered.

## Testing

- `MeditateAndNoteTests/SubscriptionViewModelTests.swift` — mock
  `EntitlementProviding` / `SubscriptionManaging`; assert buy → premium, restore,
  error mapping. No RevenueCat in the test target.
- Existing routing tests updated for the new `DomainEvent` case.

## Android follow-up (documented only)

- Same entitlement id `pro`; Kotlin `purchases-android` adapter mirroring the
  Domain protocol shape. Not built in this phase.

## Risks / open items

- RevenueCat v5 under Swift 6 strict concurrency: SDK types are not `Sendable`;
  must be quarantined and isolated inside `RevenueCatPurchasesService`.
- Adding `DomainEvent.subscriptionChanged` forces updates to every routing
  `handles` switch — verify all conformances compile.
- Exact feature→gate mapping is intentionally deferred; only the plumbing ships.
- Defaults assumed: anonymous RC appUserID; RC v5; refresh on launch + foreground.

## Verification (definition of done)

1. `verification-before-completion`: build + run tests, read output.
2. App builds on iOS simulator; paywall presents; mock-driven unit tests pass.
3. Domain files import no `CoreData`/`SwiftUI`/`RevenueCat`.
4. ViewModels depend on protocols, not the concrete `SubscriptionManager`.
5. `AppContainer` factory wiring used; no DI bypass.
