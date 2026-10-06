//
//  NoteOperationError.swift
//  MeditateAndNoteCore
//

// MARK: - NoteOperationError

/// Closed set of failures the note domain can report.
///
/// In the domain package next to `NoteDataSource`: both sides of the contract
/// need it. Swift code on Android throws this too, through the JNI adapter, and
/// a client switching on `.loadFailed` must get the same case regardless of
/// which persistence is underneath.
public enum NoteOperationError: Error, Sendable {
    case loadFailed(NoteID)
    case saveFailed
    case deleteFailed(NoteID)
    /// Separate from `deleteFailed` because there is no id to report: `deleteAll`
    /// takes none, and inventing a fake one to fit the case would mislead.
    case deleteAllFailed
    /// Same reasoning as `deleteAllFailed`: `fetchAll` has no note to attribute
    /// a decode failure to.
    case loadAllFailed
}