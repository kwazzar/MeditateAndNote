//
//  Logging.swift
//  MeditateAndNoteCore
//

import Foundation

#if canImport(os)
import os
#endif

/// Stable unified-log subsystem. Matches the app bundle identifier so output can
/// be filtered with `log stream --predicate 'subsystem == "com.quasar.MeditateAndNote"'`.
/// Lives here because managers log from Core, which cannot see app config.
public enum LogSubsystem {
    public static let main = "com.quasar.MeditateAndNote"
}

public enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

/// Platform-neutral logging facade.
///
/// The domain and application layers need to log, but `OSLog` does not exist on
/// Android and importing it would put an Apple-only dependency into
/// `MeditateAndNoteCore`. Rather than thread a logger through every initialiser,
/// this keeps the `os.Logger` call shape: declare one, call it. Where `os` is
/// available the message goes to the unified log with its subsystem and category
/// intact; elsewhere it goes to stdout with the same prefix.
///
/// Deliberately not swappable at runtime. Every call site logs unconditionally
/// today, and a settable global sink would need mutable static state, which
/// Swift 6 concurrency rejects. Add one if tests ever need to assert on logs.
public struct Logger: Sendable {
    public let subsystem: String
    public let category: String

    #if canImport(os)
    private let osLog: OSLog
    #endif

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        #if canImport(os)
        self.osLog = OSLog(subsystem: subsystem, category: category)
        #endif
    }

    public func debug(_ message: String) { emit(.debug, message) }

    public func info(_ message: String) { emit(.info, message) }

    public func warning(_ message: String) { emit(.warning, message) }

    public func error(_ message: String) { emit(.error, message) }

    private func emit(_ level: LogLevel, _ message: String) {
        #if canImport(os)
        os_log("%{public}@", log: osLog, type: level.osLogType, message)
        #else
        print("[\(level.label)] \(subsystem)/\(category): \(message)")
        #endif
    }
}

extension LogLevel {
    fileprivate var label: String {
        switch self {
        case .debug: "debug"
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        }
    }

    #if canImport(os)
    fileprivate var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        // `.warning` has no os_log type; `.default` is the conventional mapping.
        case .warning: .default
        case .error: .error
        }
    }
    #endif
}