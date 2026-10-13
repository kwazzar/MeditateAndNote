//
//  SubscriptionOperationError.swift
//  MeditateAndNoteCore
//

import Foundation

public enum SubscriptionOperationError: Error, Equatable {
    case notConfigured
    case loadFailed
    case purchaseFailed
    case restoreFailed
    case cancelled
}