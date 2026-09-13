//
//  FoundationModelsDraftServiceTests.swift
//  MeditateAndNoteTests
//
//  Cold-start classifier of the on-device draft service. Constructs real
//  LanguageModelSession.GenerationError values (public API) — no model call,
//  so these run fast on any simulator.
//

import XCTest
@testable import MeditateAndNote

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
final class FoundationModelsDraftServiceTests: XCTestCase {

    private typealias GenerationError = LanguageModelSession.GenerationError
    private typealias Context = LanguageModelSession.GenerationError.Context

    private func context() -> Context {
        Context(debugDescription: "test")
    }

    // MARK: - Transient (warmup retry)

    func testColdStartTransient_assetsUnavailable_retries() {
        XCTAssertTrue(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.assetsUnavailable(context())
        ))
    }

    func testColdStartTransient_concurrentRequests_retries() {
        XCTAssertTrue(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.concurrentRequests(context())
        ))
    }

    func testColdStartTransient_bridgedNSUnavailableError_retries() {
        // Generation can throw a bridged NSError named after the public enum
        // (domain "FoundationModels.LanguageModelSession.GenerationError", code -1)
        // while model assets are still downloading. Regression: the string "error -1"
        // used to be checked only after a cast to the enum, which never matches an
        // NSError — so this transient was misclassified and never retried.
        let bridged = NSError(
            domain: "FoundationModels.LanguageModelSession.GenerationError",
            code: -1
        )
        XCTAssertTrue(FoundationModelsAIDraftService.isColdStartTransient(bridged))
    }

    // MARK: - Non-transient (no retry)

    func testColdStartTransient_rateLimited_doesNotRetry() {
        // Rate limits route to the secondary provider, never into a retry loop.
        XCTAssertFalse(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.rateLimited(context())
        ))
    }

    func testColdStartTransient_guardrailViolation_doesNotRetry() {
        XCTAssertFalse(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.guardrailViolation(context())
        ))
    }

    func testColdStartTransient_decodingFailure_doesNotRetry() {
        XCTAssertFalse(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.decodingFailure(context())
        ))
    }

    func testColdStartTransient_exceededContextWindow_doesNotRetry() {
        XCTAssertFalse(FoundationModelsAIDraftService.isColdStartTransient(
            GenerationError.exceededContextWindowSize(context())
        ))
    }

    func testColdStartTransient_nonGenerationError_doesNotRetry() {
        struct Other: Error {}
        XCTAssertFalse(FoundationModelsAIDraftService.isColdStartTransient(Other()))
    }

    // MARK: - Suggestion parsing

    private func assertSuggestions(
        _ text: String,
        equal expected: [String],
        max: Int = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = FoundationModelsAIDraftService.parseSuggestions(from: text, max: max)
        XCTAssertEqual(result.map(\.text), expected, file: file, line: line)
    }

    func testParse_extractsJSONFromCodeFence() {
        // Observed real model output: JSON wrapped in a markdown fence.
        let raw = """
        ```json
        {"suggestions":[{"text":"Take a breath","rationale":"Calm"},{"text":"Sleep earlier","rationale":"Rest"}]}
        ```
        """
        assertSuggestions(raw, equal: ["Take a breath", "Sleep earlier"])
    }

    func testParse_extractsJSONFromProseWrapper() {
        let raw = """
        Let me think about this. The user is anxious. I'll offer a few ideas.

        Here you go: {"suggestions":[{"text":"Focus on breathing","rationale":"To relax"}]}

        Hope that helps!
        """
        assertSuggestions(raw, equal: ["Focus on breathing"])
    }

    func testParse_filtersReasoningFromPlainTextFallback() {
        let raw = """
        Let me think about what could help.
        First, I'd consider her feelings.
        - Take a walk outside
        1. Write the worries down
        Suggestions:
        """
        assertSuggestions(raw, equal: ["Take a walk outside", "Write the worries down"])
    }

    func testParse_filtersChattyOpenersAndChainOfThought() {
        // Real observed pre-fix output shape: an opener + inner monologue
        // before the actual list. Only the bullet content may survive.
        let raw = """
        Sure, I can help with that. Let me think about the best approach.

        The user is feeling anxious about a presentation. Deep breathing tends to help, and writing the worries down reduces rumination, so I'd steer there.

        Here are a few ideas to consider:
        - Write the exact fears down to externalize them
        1. Plan one concrete action for tomorrow
        - Practice a grounding exercise before I speak
        """
        assertSuggestions(
            raw,
            equal: [
                "Write the exact fears down to externalize them",
                "Plan one concrete action for tomorrow",
                "Practice a grounding exercise before I speak",
            ]
        )
    }

    func testParse_extractsJSONDespiteBlankLineInFence() {
        let raw = """
        ```json

        {"suggestions":[{"text":"Externalize the fear","rationale":"Rumination"},
         {"text":"Breathe first","rationale":"Calm"}]
        }
        ```
        """
        assertSuggestions(raw, equal: ["Externalize the fear", "Breathe first"])
    }

    func testParse_respectsMax() {
        let raw = """
        {"suggestions":[{"text":"One"},{"text":"Two"},{"text":"Three"}]}
        """
        assertSuggestions(raw, equal: ["One", "Two"], max: 2)
    }
}
#endif
