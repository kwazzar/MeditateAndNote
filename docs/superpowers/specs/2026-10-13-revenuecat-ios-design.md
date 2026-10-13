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

## Trust model (why the tests below matter)

The client is never authoritative for entitlement:

- RevenueCat verifies the receipt **server-side**. The SDK's `CustomerInfo` is
  the only source that may grant `pro`.
- `UserDefaultsSubscriptionCache` is a **UX fast-path only** (instant/offline
  display). It is user-writable and must never be able to grant or extend `pro`
  on its own — a corrupted or forged cache must degrade to "unknown/free", not
  premium.
- Expiry must be judged from RevenueCat's server-verified entitlement flags, not
  from local date math, so device clock changes cannot extend access.
- On any disagreement, RevenueCat wins: refresh that drops the entitlement must
  downgrade local state and publish `.subscriptionChanged`.

## Testing

Two groups. No RevenueCat in the test target — everything drives the mock
`EntitlementProviding` / `SubscriptionManaging` and a fake `SubscriptionCache`.

### Functional correctness

- `SubscriptionManagerTests.swift`
  - cache-first: cached `pro` is exposed immediately, then async refresh reconciles.
  - refresh granting `pro` sets `isPremium == true` and publishes exactly one
    `.subscriptionChanged`.
  - refresh with no change does **not** publish an event.
  - purchase success → premium; cancelled → `SubscriptionOperationError.cancelled`,
    status unchanged, no event.
  - restore with no purchases → `.none`.
  - `SubscriptionStatus.isActive` honors `activeEntitlements`, not mere presence.
- `SubscriptionViewModelTests.swift` / `PaywallViewModelTests.swift` — buy →
  premium UI, restore, loading, and error mapping to user-facing messages.

### Tamper / resilience (subscription "breakability")

- **Forged cache cannot grant premium**: cache seeded with `pro` while the
  service returns `.none`; after refresh `isPremium == false`, state downgraded,
  `.subscriptionChanged` published.
- **Corrupted cache data** (garbage bytes / wrong schema) → decode fails
  gracefully to "unknown/free"; no crash; no premium; no thrown error to UI.
- **Clock tampering**: `expirationDate` in the past while RC reports the
  entitlement active/inactive — assert the RC-reported flag decides, so moving
  the device clock neither extends nor revokes access.
- **Cache cannot extend expiry**: cache with future date but RC says inactive →
  free after refresh.
- **Network failure on refresh** → keep last-known status, no crash, never
  hang; no false grant when previous status was free.
- **Missing / empty API key** (`Purchases.configure` not run) → service is a
  no-op: `isPremium == false`, no crash, paywall shows an unavailable state.
- **Purchase purchase fails server-side / offline** → surfaced as error, status
  unchanged, no optimistic premium.
- **Downgrade / refund / cancellation webhook** (RC reports revoked) → next
  refresh flips to free and event fires.
- **Persistence path is not privilege**: assert `SubscriptionManager` never
  trusts `SubscriptionCache` for a *grant* — only RC paths may transition
  free → premium (regression test guarding the trust boundary).

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
