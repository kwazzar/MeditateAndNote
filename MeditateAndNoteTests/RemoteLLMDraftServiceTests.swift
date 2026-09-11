//
//  RemoteLLMDraftServiceTests.swift
//  MeditateAndNoteTests
//
//  S2 remote fallback verified without network: URLProtocol stub stands in
//  for the OpenAI-compatible endpoint (request shape, auth, retry, parsing,
//  daily cap). Uses an isolated UserDefaults suite per test.
//

import XCTest
@testable import MeditateAndNote

// MARK: - URLProtocol stub

private final class StubURLProtocol: URLProtocol {
    struct StubResponse {
        let status: Int
        let body: Data
    }

    nonisolated(unsafe) static var next: Result<StubResponse, Error>?
    nonisolated(unsafe) static var requestLog: [URLRequest] = []
    /// Queue of responses served in order (for retry tests).
    nonisolated(unsafe) static var queue: [Result<StubResponse, Error>] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestLog.append(request)
        let result: Result<StubResponse, Error>
        if !Self.queue.isEmpty {
            result = Self.queue.removeFirst()
        } else if let next = Self.next {
            result = next
        } else {
            result = .failure(URLError(.badServerResponse))
        }
        switch result {
        case .success(let stub):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.status,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        next = nil
        requestLog = []
        queue = []
    }
}

// MARK: - Stub settings

private struct StubSettingsStore: AIDraftSettingsStore {
    let settings: AIDraftSettings
    let apiKey: String?

    init(settings: AIDraftSettings = AIDraftSettings(), apiKey: String? = "test-key") {
        self.settings = settings
        self.apiKey = apiKey
    }

    func loadSettings() -> AIDraftSettings { settings }
    func saveSettings(_ settings: AIDraftSettings) {}
    func getAPIKey() -> String? { apiKey }
    func saveAPIKey(_ key: String) throws {}
    func deleteAPIKey() throws {}
}

// MARK: - Tests

final class RemoteLLMDraftServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        suiteName = "RemoteLLMTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(
        settings: AIDraftSettings = AIDraftSettings(useRemoteFallback: true),
        apiKey: String? = "test-key"
    ) -> RemoteLLMDraftService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return RemoteLLMDraftService(
            session: URLSession(configuration: config),
            settingsStore: StubSettingsStore(settings: settings, apiKey: apiKey),
            userDefaults: defaults
        )
    }

    private func makePrompt() -> AIPrompt {
        AIPrompt(
            instructions: "Give me ideas",
            noteID: NoteID(),
            context: NoteContent("calm morning meditation")
        )
    }

    private func chatJSON(texts: [(String, String)]) -> Data {
        let items = texts.map { ["text": $0.0, "rationale": $0.1] }
        let payload: [String: Any] = [
            "choices": [["message": ["content": String(
                data: try! JSONSerialization.data(
                    withJSONObject: ["suggestions": items]
                ),
                encoding: .utf8
            )!]]]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    // MARK: - Success

    func testSuggest_jsonResponse_parsesSuggestions() async throws {
        StubURLProtocol.next = .success(.init(
            status: 200,
            body: chatJSON(texts: [("Write about calm", "matches note"), ("What changed?", "prompt")])
        ))
        let suggestions = try await makeService().suggest(makePrompt())
        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[0].text, "Write about calm")
        XCTAssertEqual(suggestions[0].rationale, "matches note")
    }

    func testSuggest_plainTextResponse_fallsBackToLines() async throws {
        let payload: [String: Any] = ["choices": [["message": ["content": "First idea\n\nSecond idea\n"]]]]
        StubURLProtocol.next = .success(.init(
            status: 200,
            body: try! JSONSerialization.data(withJSONObject: payload)
        ))
        let suggestions = try await makeService().suggest(makePrompt())
        XCTAssertEqual(suggestions.map(\.text), ["First idea", "Second idea"])
    }

    func testSuggest_sendsAuthAndModel() async throws {
        StubURLProtocol.next = .success(.init(status: 200, body: chatJSON(texts: [("a", "")])))
        _ = try await makeService().suggest(makePrompt())
        let request = try XCTUnwrap(StubURLProtocol.requestLog.first)
        XCTAssertEqual(request.url?.absoluteString, AIDraftSettings.defaultEndpointURL)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        // URLSession may hand the protocol a stream instead of httpBody.
        let body = try XCTUnwrap(Self.requestBody(of: request))
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(decoded?["model"] as? String, AIDraftSettings.defaultModel)
    }

    private static func requestBody(of request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    // MARK: - Errors

    func testSuggest_rateLimitedStatus_throwsRateLimited() async {
        StubURLProtocol.next = .success(.init(status: 429, body: Data()))
        await XCTAssertThrowsErrorType(
            try await makeService().suggest(makePrompt()),
            AIDraftError.rateLimited
        )
    }

    func testSuggest_serverErrorThenSuccess_retriesOnce() async throws {
        StubURLProtocol.queue = [
            .success(.init(status: 500, body: Data())),
            .success(.init(status: 200, body: chatJSON(texts: [("recovered", "")]))),
        ]
        let suggestions = try await makeService().suggest(makePrompt())
        XCTAssertEqual(suggestions.map(\.text), ["recovered"])
        XCTAssertEqual(StubURLProtocol.requestLog.count, 2)
    }

    func testSuggest_remoteDisabled_throwsUnavailableWithoutNetwork() async {
        let service = makeService(settings: AIDraftSettings(useRemoteFallback: false))
        await XCTAssertThrowsErrorType(
            try await service.suggest(makePrompt()),
            AIDraftError.providerUnavailable
        )
        XCTAssertTrue(StubURLProtocol.requestLog.isEmpty, "Disabled service must not hit network")
    }

    func testSuggest_missingKey_throwsUnavailable() async {
        let service = makeService(apiKey: nil)
        await XCTAssertThrowsErrorType(
            try await service.suggest(makePrompt()),
            AIDraftError.providerUnavailable
        )
    }

    func testSuggest_blankKey_throwsUnavailable() async {
        let service = makeService(apiKey: "   ")
        await XCTAssertThrowsErrorType(
            try await service.suggest(makePrompt()),
            AIDraftError.providerUnavailable
        )
    }

    // MARK: - Daily cap

    func testSuggest_dailyLimitExceeded_throwsRateLimited() async throws {
        let settings = AIDraftSettings(useRemoteFallback: true, dailyGenerationLimit: 1)
        let service = makeService(settings: settings)
        StubURLProtocol.next = .success(.init(status: 200, body: chatJSON(texts: [("a", "")])))
        _ = try await service.suggest(makePrompt())
        await XCTAssertThrowsErrorType(
            try await service.suggest(makePrompt()),
            AIDraftError.rateLimited
        )
    }

    // MARK: - Factory wiring

    func testFactory_defaultWiresRemoteFallback() async {
        let service = AIDraftServiceFactory.make()
        guard let composite = service as? CompositeFallbackAIDraftService else {
            XCTFail("Factory must return the composite fallback service")
            return
        }
        XCTAssertTrue(
            composite.secondary is RemoteLLMDraftService,
            "Remote fallback must be wired by default (opt-in gated inside the service)"
        )
    }

    // MARK: - Helpers

    private func XCTAssertThrowsErrorType(
        _ expression: @autoclosure () async throws -> [AISuggestion],
        _ expected: AIDraftError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as AIDraftError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Wrong error type: \(error)", file: file, line: line)
        }
    }
}
