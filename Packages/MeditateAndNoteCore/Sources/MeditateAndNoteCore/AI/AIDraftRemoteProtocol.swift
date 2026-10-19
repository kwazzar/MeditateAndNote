//
//  AIDraftRemoteProtocol.swift
//  MeditateAndNoteCore
//
//  The wire protocol of an OpenAI-compatible chat-completions endpoint, shared
//  by both platforms.
//
//  It lives in the core because two transports speak it: iOS talks to it
//  through URLSession, Android through HttpURLConnection. Only the transport
//  differs - the instructions, the request body, the envelope and the
//  suggestion parsing must not, or the two apps would drift into asking the
//  model different things and reading different answers out of the same
//  response.
//

import Foundation

public enum AIDraftRemoteProtocol {

    // MARK: - Request text

    /// The request the editor sends when the user just taps the sparkles:
    /// continue the note, or ask questions when there is nothing written yet.
    public static func defaultRequest(isGrounded: Bool) -> String {
        isGrounded
            ? "Give me ideas to continue this note"
            : "I have not written anything yet — ask me questions to start"
    }

    // MARK: - Prompt

    /// System instructions for the model. Grounded prompts continue the note;
    /// ungrounded ones ask the user questions instead of writing for them.
    public static func systemInstructions(for prompt: AIPrompt) -> String {
        if prompt.isGrounded {
            return """
            You are a reflective journaling assistant in an app called MeditateAndNote. \
            Read the user's note and their request, then offer concise, thoughtful \
            suggestions to help them continue. Every suggestion must name a specific \
            moment, detail or feeling from the note above — generic advice is not \
            acceptable. Never invent personal facts. Keep each suggestion under 140 \
            characters. Return suggestions as a JSON object in this format: \
            {"suggestions": [{"text": "suggestion text", "rationale": "short reason"}]}
            """
        }

        return """
        You are a reflective journaling assistant in an app called MeditateAndNote. \
        The user has not written anything yet, so there is no note to continue. \
        Ask reflective questions that help them start — never write the note for \
        them, never invent personal facts. Keep each question under 140 characters. \
        Return the questions as a JSON object in this format: \
        {"suggestions": [{"text": "the question", "rationale": "short reason"}]}
        """
    }

    /// The user message: the request plus the frozen note content.
    public static func userMessage(for prompt: AIPrompt) -> String {
        let context = prompt.context.rawValue.isEmpty ? "(no note content yet)" : prompt.context.rawValue
        return """
        Request: \(prompt.instructions)

        Current note content:
        \(context)
        """
    }

    // MARK: - Request

    /// The JSON body of a chat-completions request.
    public static func requestBody(model: String, system: String, user: String) -> String {
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.7,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // MARK: - Response

    /// The assistant's message out of a chat-completions response, or nil when
    /// the envelope carries none.
    public static func content(fromResponse response: String) -> String? {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content
    }

    /// Suggestions out of the model's answer. A JSON object is the expected
    /// shape; plain lines are the fallback when the model ignores it.
    public static func suggestions(from content: String, max: Int) -> [AISuggestion] {
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["suggestions"] as? [[String: Any]] {
            return items.compactMap { item -> AISuggestion? in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                return AISuggestion(text: text, rationale: item["rationale"] as? String ?? "")
            }.prefix(max).map { $0 }
        }

        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(max)

        return lines.map { AISuggestion(text: String($0)) }
    }
}
