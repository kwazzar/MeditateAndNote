//
//  TextMeasurer.swift
//  MeditateAndNoteCore
//

import Foundation

/// Platform font metrics used by `PaginationEngine`.
/// iOS implements with `UIFont`; Android with `android.graphics.Paint`.
/// All values are in the same abstract units as the `PageSize` passed to the engine.
public protocol TextMeasurer: Sendable {
    /// Rendered width of a single-line string.
    func width(of text: String) -> Double
    /// Height of one laid-out text line (including leading).
    func lineHeight() -> Double
}
