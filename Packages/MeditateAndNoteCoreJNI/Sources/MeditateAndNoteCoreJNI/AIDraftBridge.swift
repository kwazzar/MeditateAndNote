//
//  AIDraftBridge.swift
//  MeditateAndNoteCoreJNI
//
//  JNI entry points for the AI draft bar of the note editor.
//
//  Division of labour: Swift owns the domain — the prompt, the session state
//  machine, the free-quota rule and the parsing of a provider's answer. Kotlin
//  owns the transport (HTTP) and the storage (settings, quota counter). Kotlin
//  never parses a provider answer and Swift never speaks HTTP.
//
//  Every call answers with one JSON envelope:
//    {"ok": true,  "session": {…}}
//    {"ok": false, "error": "freeQuotaExhausted"}
//  The session is the domain aggregate, encoded by Codable; Kotlin keeps it as
//  an opaque string and hands it back for the next transition.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// Kotlin's provider object: settings in, HTTP out.
@JavaClass("com.mn.android.data.AIDraftProvider")
public class AIDraftProvider: JavaObject {}

private let draftLogger = Logger(subsystem: "com.mn.core", category: "AIDraft")

// MARK: - Commands

/// Starts a generation for a note. Kotlin side: AIDraftSource.kt
@_cdecl("Java_com_mn_android_data_AIDraftSource_startDraft")
public func Java_com_mn_android_data_AIDraftSource_startDraft(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jInstruction: jstring?,
    jContext: jstring?,
    jNoteId: jstring?
) -> jstring? {
    let instruction = String(fromJNI: jInstruction, in: environment)
    let context = String(fromJNI: jContext, in: environment)
    let noteId = String(fromJNI: jNoteId, in: environment)

    let envelope = startDraft(instruction: instruction, context: context, noteId: noteId)
    return envelope.getJNILocalRefValue(in: environment)
}

/// Moves one suggestion into the accepted pool.
@_cdecl("Java_com_mn_android_data_AIDraftSource_acceptSuggestion")
public func Java_com_mn_android_data_AIDraftSource_acceptSuggestion(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jSession: jstring?,
    jSuggestionId: jstring?
) -> jstring? {
    let sessionJSON = String(fromJNI: jSession, in: environment)
    let suggestionId = String(fromJNI: jSuggestionId, in: environment)

    let envelope = mutateSession(sessionJSON) { session in
        guard let id = UUID(uuidString: suggestionId) else { return .failure(.noContext) }
        let suggestion = session.suggestions.first { $0.id == id }
            ?? session.acceptedSuggestions.first { $0.id == id }
        guard let suggestion else { return .failure(.noContext) }
        if !session.acceptedSuggestions.contains(where: { $0.id == id }) {
            _ = session.accept(suggestion)
        }
        return .success(session)
    }
    return envelope.getJNILocalRefValue(in: environment)
}

/// Moves every pending suggestion into the accepted pool.
@_cdecl("Java_com_mn_android_data_AIDraftSource_acceptAll")
public func Java_com_mn_android_data_AIDraftSource_acceptAll(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jSession: jstring?
) -> jstring? {
    let sessionJSON = String(fromJNI: jSession, in: environment)

    let envelope = mutateSession(sessionJSON) { session in
        session.acceptAll()
        return .success(session)
    }
    return envelope.getJNILocalRefValue(in: environment)
}

/// Sends an accepted suggestion back to pending.
@_cdecl("Java_com_mn_android_data_AIDraftSource_rejectSuggestion")
public func Java_com_mn_android_data_AIDraftSource_rejectSuggestion(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jSession: jstring?,
    jSuggestionId: jstring?
) -> jstring? {
    let sessionJSON = String(fromJNI: jSession, in: environment)
    let suggestionId = String(fromJNI: jSuggestionId, in: environment)

    let envelope = mutateSession(sessionJSON) { session in
        guard let id = UUID(uuidString: suggestionId),
              let suggestion = session.acceptedSuggestions.first(where: { $0.id == id }) else {
            return .failure(.noContext)
        }
        _ = session.reject(suggestion)
        return .success(session)
    }
    return envelope.getJNILocalRefValue(in: environment)
}

/// Cancels a generation.
@_cdecl("Java_com_mn_android_data_AIDraftSource_cancel")
public func Java_com_mn_android_data_AIDraftSource_cancel(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jSession: jstring?
) -> jstring? {
    let sessionJSON = String(fromJNI: jSession, in: environment)

    let envelope = mutateSession(sessionJSON) { session in
        session.cancel()
        return .success(session)
    }
    return envelope.getJNILocalRefValue(in: environment)
}

/// The stored session for a note, so the editor can restore the draft the
/// user left behind instead of burning another generation.
@_cdecl("Java_com_mn_android_data_AIDraftSource_session")
public func Java_com_mn_android_data_AIDraftSource_session(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jNoteId: jstring?
) -> jstring? {
    let noteId = String(fromJNI: jNoteId, in: environment)
    let envelope = storedSession(noteId: noteId)
    return envelope.getJNILocalRefValue(in: environment)
}

/// Drops the stored session of a note - the note is gone, so is its draft.
@_cdecl("Java_com_mn_android_data_AIDraftSource_discardSession")
public func Java_com_mn_android_data_AIDraftSource_discardSession(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass,
    jNoteId: jstring?
) {
    let noteId = String(fromJNI: jNoteId, in: environment)
    guard let uuid = UUID(uuidString: noteId) else { return }
    try? sessions.deleteSync(noteID: NoteID(rawValue: uuid))
}

// MARK: - Domain flow

/// The generation pipeline: prompt, quota gate, provider call, parse, fulfil.
///
/// Android has no entitlement yet, so every user is on the free tier and the
/// lifetime allowance applies — the same rule Core keeps for iOS.
private func startDraft(instruction: String, context: String, noteId: String) -> String {
    guard let uuid = UUID(uuidString: noteId) else {
        return failure(.noContext)
    }

    let prompt = AIPrompt(
        instructions: instruction,
        noteID: NoteID(rawValue: uuid),
        context: NoteContent(context)
    )
    // An empty instruction means "the user just tapped the sparkles" - the
    // default request depends on whether there is anything to continue.
    let resolved = prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? AIPrompt(
            instructions: AIDraftRemoteProtocol.defaultRequest(isGrounded: prompt.isGrounded),
            noteID: prompt.noteID,
            context: prompt.context
        )
        : prompt

    guard AIDraftQuota.allowsDraft(isPremium: false, used: quota.used()) else {
        draftLogger.info("free draft quota exhausted")
        return failure(.freeQuotaExhausted)
    }

    var session = AIDraftSession(noteID: resolved.noteID, prompt: resolved)
    session.beginGeneration()
    let startedAt = Date()

    do {
        let settings = try providerSettings()
        let body = AIDraftRemoteProtocol.requestBody(
            model: settings.model,
            system: AIDraftRemoteProtocol.systemInstructions(for: resolved),
            user: AIDraftRemoteProtocol.userMessage(for: resolved)
        )
        let response = try providerPost(endpoint: settings.endpoint, body: body)
        guard let content = AIDraftRemoteProtocol.content(fromResponse: response) else {
            session.fail(.emptyResponse)
            return failure(.emptyResponse)
        }

        session.fulfil(with: AIDraftRemoteProtocol.suggestions(
            from: content,
            max: resolved.maxSuggestions
        ))

        guard session.state == .ready else {
            return failure(.emptyResponse)
        }

        // A generation that produced suggestions is the only one that burns
        // the free allowance — a failed attempt does not count.
        quota.record()
        let metric = metric(
            kind: "generationCompleted",
            latencyMs: elapsedMs(since: startedAt),
            suggestionCount: session.suggestions.count
        )
        save(session)
        return success(session, metric: metric)
    } catch let error as AIDraftError {
        session.fail(error)
        return failure(error, metric: metric(kind: "generationFailed", errorKind: error.metricKind.rawValue))
    } catch {
        draftLogger.warning("draft generation failed: \(error)")
        session.fail(.providerUnavailable)
        return failure(
            .providerUnavailable,
            metric: metric(kind: "generationFailed", errorKind: ErrorKind.unavailable.rawValue)
        )
    }
}

/// The stored session for a note, if there is one.
private func storedSession(noteId: String) -> String {
    guard let uuid = UUID(uuidString: noteId),
          let session = try? sessions.fetchSync(noteID: NoteID(rawValue: uuid)) else {
        return encode(["ok": true])
    }
    return success(session)
}

/// Keeps the session where the next editor visit finds it.
private func save(_ session: AIDraftSession) {
    try? sessions.saveSync(session)
}

/// The sanitized telemetry row for one event. Only counts, latency and a
/// typed kind — never prompt text or the model's answer.
private func metric(
    kind: String,
    latencyMs: Int? = nil,
    suggestionCount: Int? = nil,
    errorKind: String? = nil,
    suggestionIndex: Int? = nil
) -> [String: Any] {
    var record: [String: Any] = ["kind": kind]
    if let latencyMs { record["latencyMs"] = latencyMs }
    if let suggestionCount { record["suggestionCount"] = suggestionCount }
    if let errorKind { record["errorKind"] = errorKind }
    if let suggestionIndex { record["suggestionIndex"] = suggestionIndex }
    return record
}

private func elapsedMs(since start: Date) -> Int {
    Int(Date().timeIntervalSince(start) * 1000)
}

/// Applies a domain transition to a session Kotlin handed back.
private func mutateSession(
    _ sessionJSON: String,
    _ transition: (inout AIDraftSession) -> Result<AIDraftSession, AIDraftError>
) -> String {
    guard let data = sessionJSON.data(using: .utf8),
          var session = try? JSONDecoder().decode(AIDraftSession.self, from: data) else {
        return failure(.noContext)
    }

    switch transition(&session) {
    case .success(let updated):
        save(updated)
        return success(updated)
    case .failure(let error):
        return failure(error)
    }
}

// MARK: - Kotlin calls

private struct ProviderSettings {
    let endpoint: String
    let model: String
}

/// The user's endpoint and model. Empty values fall back to the domain
/// defaults, so an unconfigured app still talks to a sane provider.
private func providerSettings() throws -> ProviderSettings {
    let json = try JavaClass<AIDraftProvider>()
        .dynamicJavaStaticMethodCall(methodName: "settings", resultType: String.self)
    guard let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return ProviderSettings(
            endpoint: AIDraftSettings.defaultEndpointURL,
            model: AIDraftSettings.defaultModel
        )
    }

    let endpoint = (object["endpoint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let model = (object["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return ProviderSettings(
        endpoint: endpoint.isEmpty ? AIDraftSettings.defaultEndpointURL : endpoint,
        model: model.isEmpty ? AIDraftSettings.defaultModel : model
    )
}

/// Posts the request body and returns the raw provider response.
///
/// Kotlin answers with `{"ok":true,"body":"…"}` or
/// `{"ok":false,"status":429}` — the transport reports failures as data, so
/// this side never has to read an exception message.
private func providerPost(endpoint: String, body: String) throws -> String {
    let json = try JavaClass<AIDraftProvider>()
        .dynamicJavaStaticMethodCall(
            methodName: "post",
            arguments: endpoint,
            body,
            resultType: String.self
        )
    guard let data = json.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw AIDraftError.providerUnavailable
    }

    if (object["ok"] as? Bool) == true {
        return (object["body"] as? String) ?? ""
    }
    if (object["status"] as? Int) == 429 {
        throw AIDraftError.rateLimited
    }
    throw AIDraftError.providerUnavailable
}

/// The free-generation counter. The storage is Kotlin's, the limit and the
/// rule are Core's - see `KotlinAIDraftQuotaStore`.
private let quota = KotlinAIDraftQuotaStore()

/// The stored draft sessions. Kotlin keeps the bytes, Core owns the
/// aggregate - see `KotlinAIDraftSessionStore`.
private let sessions = KotlinAIDraftSessionStore()

// MARK: - Envelopes

private func success(_ session: AIDraftSession, metric: [String: Any]? = nil) -> String {
    let sessionObject = (try? JSONSerialization.jsonObject(
        with: JSONEncoder().encode(session)
    )) ?? [String: Any]()
    var payload: [String: Any] = ["ok": true, "session": sessionObject]
    if let metric { payload["metric"] = metric }
    return encode(payload)
}

private func failure(_ error: AIDraftError, metric: [String: Any]? = nil) -> String {
    var payload: [String: Any] = ["ok": false, "error": error.rawValue]
    if let metric { payload["metric"] = metric }
    return encode(payload)
}

private func encode(_ payload: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let json = String(data: data, encoding: .utf8) else {
        return "{\"ok\":false,\"error\":\"providerUnavailable\"}"
    }
    return json
}
