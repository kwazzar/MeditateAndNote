//
//  BookBookmarkProbes.swift
//  MeditateAndNoteCoreJNI
//
//  Device probe for the reader's marks on Android: the `KotlinBookmarkStore`
//  round trip through SharedPreferences.
//
//  Results are flags written into a LongArray Kotlin allocated — same rule as
//  every other probe: Kotlin cannot observe Swift replacing an out-param.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// Kotlin side: `BookmarkStoreProbe.kt`. Slots (7):
/// 0 saved, 1 loaded count, 2 highlight text survived, 3 position survived,
/// 4 note link survived, 5 delete cleared, 6 threw.
@_cdecl("Java_com_mn_android_debug_NativeProbe_bookmarkProbe")
public func Java_com_mn_android_debug_NativeProbe_bookmarkProbe(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    out: jlongArray
) {
    let store = KotlinBookmarkStore()
    var results = [Int64](repeating: 0, count: 7)
    let bookID = BookID()

    do {
        let mark = Bookmark.highlight(
            bookID,
            at: ReadingPosition(chapterIndex: 2, blockIndex: 3, characterOffset: 40),
            text: "a marked passage",
            noteID: NoteID()
        )
        try store.saveSync(mark)
        results[0] = 1

        // Scoped to the probe's own mark: the store may hold the reader's
        // real highlights, and a count check would fail on their data.
        let mine = try store.allSync().first { $0.id == mark.id }
        results[1] = mine == nil ? 0 : 1
        results[2] = mine?.text == "a marked passage" ? 1 : 0
        results[3] = mine?.position == mark.position ? 1 : 0
        results[4] = mine?.noteID == mark.noteID ? 1 : 0

        try store.deleteSync(mark.id)
        results[5] = try store.allSync().first { $0.id == mark.id } == nil ? 1 : 0
    } catch {
        KotlinBookStore.logProbeFailure(error)
        results[6] = 1
    }

    writeValues(results, to: out, in: environment)
}
