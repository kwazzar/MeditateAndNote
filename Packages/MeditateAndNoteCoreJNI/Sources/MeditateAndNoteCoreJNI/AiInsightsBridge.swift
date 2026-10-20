//
//  AiInsightsBridge.swift
//  MeditateAndNoteCoreJNI
//
//  JNI entry points for the note-insights section of the notes list.
//
//  The analysis itself stays in the domain: Core's `HeuristicNoteAnalyzer`
//  and `NoteInsightRemoteProtocol` produce the insights, and only the result
//  crosses the boundary. Kotlin never re-implements the theme/summary/tag
//  rules — it decodes the JSON this file returns and renders it, the same
//  split the streak-insights bridge uses.
//
//  Kotlin side: NoteInsightsSource.kt
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

private let bridgeLogger = Logger(subsystem: "com.mn.core", category: "AiInsights")

// MARK: - Commands

/// Returns one JSON document: {"insights":[{id, summary, tags[], themes[{label, relevance}]}]}.
///
/// The insights come back in note order — the blob store hands the notes over
/// newest first, so index 0 is the freshest note, and the screen shows the
/// first three.
///
/// This is the heuristic pass: it always works and it costs nothing, so the
/// section has something to show before a provider is asked.
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

/// The persisted insights — no analysis, no provider call.
///
/// Answers `{"ok":true,"insights":[…],"source":"stored"}`. An empty store is
/// not an error: the screen then falls back to the heuristic pass.
@_cdecl("Java_com_mn_android_data_NoteInsightsSource_stored")
public func Java_com_mn_android_data_NoteInsightsSource_stored(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass
) -> jstring? {
    let insights = (try? KotlinNoteInsightStore().fetchAllSync()) ?? []
    return encode([
        "ok": true,
        "insights": insightObjects(insights),
        "source": "stored",
    ]).getJNILocalRefValue(in: environment)
}

/// An analysis pass: the provider first, the heuristic when there is no
/// provider or the answer carries nothing usable. The result is persisted, so
/// the next open costs nothing.
///
/// Answers `{"ok":true,"insights":[…],"source":"llm"|"heuristic"}` or
/// `{"ok":false,"error":"…"}`.
@_cdecl("Java_com_mn_android_data_NoteInsightsSource_analyze")
public func Java_com_mn_android_data_NoteInsightsSource_analyze(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass
) -> jstring? {
    return analyzeInsights().getJNILocalRefValue(in: environment)
}

// MARK: - Analysis

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
    return insightObjects(insights)
}

/// The pass behind the refresh button: provider first, heuristic as the
/// fallback, the result persisted.
private func analyzeInsights() -> String {
    guard let notes = try? KotlinNoteDataSource().fetchAllSync() else {
        return encode(["ok": false, "error": "notesUnavailable"])
    }
    let analyzable = notes.filter { !HeuristicNoteAnalyzer.combinedText(of: $0).isEmpty }
    guard !analyzable.isEmpty else {
        return encode(["ok": true, "insights": [], "source": "heuristic"])
    }

    let batch = Array(analyzable.prefix(NoteInsightRemoteProtocol.maxNotes))
    var source = "llm"
    var insights: [NoteInsight] = []
    if let remote = remoteInsights(for: batch), !remote.isEmpty {
        insights = remote
    } else {
        source = "heuristic"
        insights = (try? HeuristicNoteAnalyzer().analyzeSync(notes: notes)) ?? []
    }

    persist(insights, knownNoteIDs: Set(notes.map(\.id)))
    return encode([
        "ok": true,
        "insights": insightObjects(insights),
        "source": source,
    ])
}

/// The model's answer, or nil when there is no provider or nothing usable
/// came back. The same provider, the same model and the same request body
/// the AI draft uses — only the instructions differ.
private func remoteInsights(for notes: [Note]) -> [NoteInsight]? {
    guard let settings = try? providerSettings() else { return nil }
    let body = AIDraftRemoteProtocol.requestBody(
        model: settings.model,
        system: NoteInsightRemoteProtocol.systemInstructions(),
        user: NoteInsightRemoteProtocol.batchPrompt(for: notes)
    )
    guard let response = try? providerPost(endpoint: settings.endpoint, body: body),
          let content = AIDraftRemoteProtocol.content(fromResponse: response) else {
        bridgeLogger.info("note insights: no provider answer — using the heuristic")
        return nil
    }
    return NoteInsightRemoteProtocol.insights(from: content, notes: notes)
}

/// Stores the insights and drops the ones whose note is gone.
private func persist(_ insights: [NoteInsight], knownNoteIDs: Set<NoteID>) {
    let store = KotlinNoteInsightStore()
    for insight in insights where !insight.isEmpty {
        try? store.saveSync(insight)
    }
    guard let stored = try? store.fetchAllSync() else { return }
    for insight in stored where !knownNoteIDs.contains(insight.noteID) {
        try? store.deleteSync(noteID: insight.noteID)
    }
}

// MARK: - Encoding

/// Insights as the flat records Kotlin renders: one object per insight.
private func insightObjects(_ insights: [NoteInsight]) -> [[String: Any]] {
    insights.map { insight in
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
