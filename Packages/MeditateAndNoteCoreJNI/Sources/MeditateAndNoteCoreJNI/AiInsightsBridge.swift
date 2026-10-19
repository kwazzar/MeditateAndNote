//
//  AiInsightsBridge.swift
//  MeditateAndNoteCoreJNI
//
//  JNI entry point for the note-insights section of the notes list.
//
//  The analysis itself stays in the domain: Core's `HeuristicNoteAnalyzer`
//  produces the insights, and only the result crosses the boundary. Kotlin
//  never re-implements the theme/summary/tag rules — it decodes the JSON
//  this file returns and renders it, the same split the streak-insights
//  bridge uses.
//
//  Kotlin side: NoteInsightsSource.kt
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

private let bridgeLogger = Logger(subsystem: "com.mn.core", category: "AiInsights")

/// Returns one JSON document: {"insights":[{id, summary, tags[], themes[{label, relevance}]}]}.
///
/// The insights come back in note order — the blob store hands the notes over
/// newest first, so index 0 is the freshest note, and the screen shows the
/// first three.
@_cdecl("Java_com_mn_android_data_NoteInsightsSource_read")
public func Java_com_mn_android_data_NoteInsightsSource_read(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass
) -> jstring? {
    let payload: [String: Any] = ["insights": noteInsights()]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else {
        bridgeLogger.warning("note insights failed to serialize")
        return "{\"insights\":[]}".getJNILocalRefValue(in: environment)
    }
    return json.getJNILocalRefValue(in: environment)
}

/// Analyzes every stored note. An empty store — or a store whose notes have
/// no analyzable text — is not an error: it yields no insights and the screen
/// stays hidden.
func noteInsights() -> [[String: Any]] {
    guard let notes = try? KotlinNoteDataSource().fetchAllSync() else {
        bridgeLogger.warning("note insights: notes could not be read")
        return []
    }
    guard let insights = try? HeuristicNoteAnalyzer().analyzeSync(notes: notes) else {
        return []
    }
    return insights.map { insight in
        [
            "id": insight.noteID.rawValue.uuidString,
            "summary": insight.summary,
            "tags": insight.suggestedTags,
            "themes": insight.themes.map { theme in
                ["label": theme.label, "relevance": theme.relevance]
            },
        ]
    }
}
