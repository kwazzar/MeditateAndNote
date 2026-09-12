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

}
#endif
