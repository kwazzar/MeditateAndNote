//
//  SubscriptionOffering.swift
//  MeditateAndNoteCore
//

import Foundation

/// A RevenueCat offering, decoupled from the SDK's `Offering` type so the
/// Domain layer never depends on RevenueCat.
public struct SubscriptionOffering: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let packages: [SubscriptionPackage]

    public init(id: String, title: String, packages: [SubscriptionPackage]) {
        self.id = id
        self.title = title
        self.packages = packages
    }
}

/// A purchasable package within an offering.
public struct SubscriptionPackage: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let priceString: String

    public init(id: String, title: String, priceString: String) {
        self.id = id
        self.title = title
        self.priceString = priceString
    }
}