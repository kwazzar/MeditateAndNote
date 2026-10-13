//
//  RevenueCatPurchasesService.swift
//  MeditateAndNote
//

import Foundation
import MeditateAndNoteCore
import RevenueCat

/// Maps RevenueCat's SDKS onto the domain `SubscriptionManaging` contract.
/// The only file in the app that imports RevenueCat.
///
/// Trust model: this is the sole grant authority. Every answer comes from
/// `CustomerInfo` as reported by RevenueCat; the app never decides it is
/// entitled on its own.
struct RevenueCatPurchasesService: SubscriptionManaging {
    let isConfigured: Bool
    private let proEntitlementID: String

    private init(isConfigured: Bool, proEntitlementID: String) {
        self.isConfigured = isConfigured
        self.proEntitlementID = proEntitlementID
    }

    /// Configures the RevenueCat SDK (once) and returns a service bound to it.
    static func configure(apiKey: String, proEntitlementID: String) -> RevenueCatPurchasesService {
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }
        return RevenueCatPurchasesService(isConfigured: Purchases.isConfigured, proEntitlementID: proEntitlementID)
    }

    func offerings() async throws -> [SubscriptionOffering] {
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else { return [] }
        return [
            SubscriptionOffering(
                id: current.identifier,
                title: current.serverDescription,
                packages: current.availablePackages.map(Self.mapPackage)
            )
        ]
    }

    func purchase(_ package: SubscriptionPackage) async throws -> SubscriptionStatus {
        guard let rcPackage = try await self.rcPackage(for: package) else {
            throw SubscriptionOperationError.loadFailed
        }
        do {
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: rcPackage)
            return Self.map(customerInfo, proEntitlementID: proEntitlementID)
        } catch {
            if (error as NSError).code == ErrorCode.purchaseCancelledError.rawValue {
                throw SubscriptionOperationError.cancelled
            }
            throw SubscriptionOperationError.purchaseFailed
        }
    }

    func restore() async throws -> SubscriptionStatus {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            return Self.map(customerInfo, proEntitlementID: proEntitlementID)
        } catch {
            throw SubscriptionOperationError.restoreFailed
        }
    }

    func refresh() async -> SubscriptionStatus {
        guard isConfigured else { return .none }
        let info = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
        guard let info else { return .none }
        return Self.map(info, proEntitlementID: proEntitlementID)
    }

    private func rcPackage(for package: SubscriptionPackage) async throws -> RevenueCat.Package? {
        guard let current = try? await Purchases.shared.offerings().current else { return nil }
        return current.availablePackages.first { $0.storeProduct.productIdentifier == package.id }
    }

    private static func mapPackage(_ package: RevenueCat.Package) -> SubscriptionPackage {
        SubscriptionPackage(
            id: package.storeProduct.productIdentifier,
            title: package.storeProduct.localizedTitle,
            priceString: package.storeProduct.localizedPriceString
        )
    }

    private static func map(_ info: CustomerInfo, proEntitlementID: String) -> SubscriptionStatus {
        let entitlement = info.entitlements.active[proEntitlementID]
        return SubscriptionStatus(
            activeEntitlements: entitlement == nil ? [] : [.pro],
            expirationDate: entitlement?.expirationDate,
            willRenew: entitlement?.willRenew ?? false,
            productIdentifier: entitlement?.productIdentifier
        )
    }
}