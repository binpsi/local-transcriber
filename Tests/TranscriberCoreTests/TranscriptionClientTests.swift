import Foundation
import XCTest
@testable import TranscriberCore

final class TranscriptionClientTests: XCTestCase {
    private var directory: URL!
    private var file: URL!
    private var session: URLSession!
    private var client: TranscriptionClient!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("private-patient-name.wav")
        try Data("test audio bytes".utf8).write(to: file)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAudioURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = TranscriptionClient(session: session)
        MockAudioURLProtocol.handler = nil
        MockAudioURLProtocol.stopped = nil
    }

    override func tearDownWithError() throws {
        session.invalidateAndCancel()
        MockAudioURLProtocol.handler = nil
        MockAudioURLProtocol.stopped = nil
        try FileManager.default.removeItem(at: directory)
    }

    func testTranscribesJSONAtFixedEndpointWithAuthorization() async throws {
        MockAudioURLProtocol.handler = { request, protocolInstance in
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=LocalTranscriber-") == true)
            protocolInstance.respond(status: 200, body: #"{"text":" 你好，世界。\n","languages":[{"code":"zh"}]}"#)
        }
        let result = try await client.transcribe(fileURL: file, apiKey: " test-key\n", options: .init())
        XCTAssertEqual(result, "你好，世界。")
    }

    func testMultipartHasArrayHintsCorrectFramingAndPrivateFilename() async throws {
        let bodyURL = try await client.makeMultipartFile(fileURL: file, options: .init(languages: ["zh", "en"], keywords: ["AiTmed", "医学术语"], prompt: "准确转写。"), boundary: "test-boundary")
        defer { try? FileManager.default.removeItem(at: bodyURL.deletingLastPathComponent()) }
        let body = try String(contentsOf: bodyURL, encoding: .utf8)
        XCTAssertTrue(body.contains("name=\"model\"\r\n\r\ngpt-transcribe\r\n"))
        XCTAssertTrue(body.contains("name=\"response_format\"\r\n\r\njson\r\n"))
        XCTAssertTrue(body.contains("name=\"languages[]\"\r\n\r\nzh\r\n"))
        XCTAssertTrue(body.contains("name=\"languages[]\"\r\n\r\nen\r\n"))
        XCTAssertTrue(body.contains("name=\"keywords[]\"\r\n\r\n医学术语\r\n"))
        XCTAssertTrue(body.contains("name=\"prompt\"\r\n\r\n准确转写。\r\n"))
        XCTAssertTrue(body.contains("filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\ntest audio bytes\r\n"))
        XCTAssertFalse(body.contains("private-patient-name"))
        XCTAssertTrue(body.hasSuffix("\r\n--test-boundary--\r\n"))
        let attributes = try FileManager.default.attributesOfItem(atPath: bodyURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testInvalidKeyAndHintLimitsNeverSendRequests() async throws {
        MockAudioURLProtocol.handler = { _, _ in XCTFail("Validation must happen before networking") }
        await assertError(.invalidAPIKey, key: " \n")
        await assertError(.invalidAPIKey, key: "test\nkey")
        await assertError(.invalidLanguages, options: .init(languages: ["Chinese"]))
        await assertError(.invalidLanguages, options: .init(languages: ["zh", "en", "ja", "ko", "fr", "de"]))
        await assertError(.invalidKeywords, options: .init(keywords: [String(repeating: "字", count: 101)]))
        await assertError(.invalidPrompt, options: .init(prompt: String(repeating: "字", count: 4_001)))
    }

    func testAcceptsCantoneseAndRegionalLanguageCodes() async throws {
        let requests = expectation(description: "Valid language hints reach the API")
        requests.expectedFulfillmentCount = 3
        MockAudioURLProtocol.handler = { _, instance in
            requests.fulfill()
            instance.respond(status: 200, body: #"{"text":"語言提示有效。"}"#)
        }
        for languages in [["yue"], ["zh-cn"], [" ZH-CN ", "yue"]] {
            let result = try await client.transcribe(fileURL: file, apiKey: "test-key", options: .init(languages: languages))
            XCTAssertEqual(result, "語言提示有效。")
        }
        await fulfillment(of: [requests], timeout: 3)
    }

    func testRejectsMalformedLanguageCodesAndForbiddenKeywordCharactersBeforeNetwork() async throws {
        MockAudioURLProtocol.handler = { _, _ in XCTFail("Invalid hints must not reach the API") }
        for language in ["z", "zh_CN", "zh--cn", "en1", "zh-", "zh-cn-extra"] {
            await assertError(.invalidLanguages, options: .init(languages: [language]))
        }
        // Check leading and trailing newlines as well: trimming must not hide forbidden input.
        for keyword in ["<name", "name>", "a\rb", "a\nb", "\nname", "name\r", "a\0b"] {
            await assertError(.invalidKeywords, options: .init(keywords: [keyword]))
        }
    }

    func testRejectsOversizedEmptyMissingAndUnsupportedFilesBeforeNetwork() async throws {
        MockAudioURLProtocol.handler = { _, _ in XCTFail("Invalid files must not be uploaded") }
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(TranscriptionClient.maximumFileBytes + 1))
        try handle.close()
        await assertError(.fileTooLarge)
        try Data().write(to: file)
        await assertError(.emptyFile)
        try FileManager.default.removeItem(at: file)
        await assertError(.unreadableFile)
        file = directory.appendingPathComponent("audio.exe")
        try Data("audio".utf8).write(to: file)
        await assertError(.unsupportedFileFormat)
    }

    func testHTTPFailuresMapToUsefulErrorsWithoutExposingServerText() async throws {
        let cases: [(Int, TranscriptionError)] = [
            (401, .authenticationFailed), (403, .permissionDenied), (404, .modelUnavailable),
            (413, .requestTooLarge), (429, .rateLimited), (500, .serverUnavailable),
            (503, .serverUnavailable), (400, .rejectedRequest(statusCode: 400)), (307, .redirectRefused)
        ]
        for (status, expected) in cases {
            MockAudioURLProtocol.handler = { _, instance in
                instance.respond(status: status, body: #"{"error":{"message":"secret-server-message","code":null,"type":"api_error"}}"#)
            }
            await assertError(expected)
            XCTAssertFalse(expected.localizedDescription.contains("secret-server-message"))
        }
        MockAudioURLProtocol.handler = { _, instance in
            instance.respond(status: 429, body: #"{"error":{"code":"insufficient_quota","type":"insufficient_quota"}}"#)
        }
        await assertError(.quotaExceeded)
    }

    func testMalformedAndEmptyResponses() async throws {
        for body in ["not json", #"{"text":null}"#, #"{"unexpected":"value"}"#] {
            MockAudioURLProtocol.handler = { _, instance in instance.respond(status: 200, body: body) }
            await assertError(.unexpectedResponse)
        }
        MockAudioURLProtocol.handler = { _, instance in instance.respond(status: 200, body: #"{"text":"  \n "}"#) }
        await assertError(.emptyTranscription)
    }

    func testNetworkFailuresHaveControlledDescriptions() async throws {
        let failures: [(URLError.Code, TranscriptionError)] = [
            (.notConnectedToInternet, .networkUnavailable), (.timedOut, .requestTimedOut),
            (.networkConnectionLost, .networkFailure)
        ]
        for (code, expected) in failures {
            MockAudioURLProtocol.handler = { _, instance in
                instance.client?.urlProtocol(instance, didFailWithError: URLError(code))
            }
            await assertError(expected)
        }
    }

    func testCancellationStopsAnInFlightUpload() async throws {
        let started = expectation(description: "Network request started")
        let stopped = expectation(description: "Network request stopped")
        MockAudioURLProtocol.handler = { _, _ in started.fulfill() }
        MockAudioURLProtocol.stopped = { stopped.fulfill() }
        let upload = Task { try await client.transcribe(fileURL: file, apiKey: "test-key") }
        await fulfillment(of: [started], timeout: 3)
        upload.cancel()
        do {
            _ = try await upload.value
            XCTFail("Cancellation must not yield a transcript")
        } catch is CancellationError {
            // Cancellation must remain distinct from a network error in the UI.
        } catch {
            XCTFail("Expected CancellationError, received \(type(of: error))")
        }
        await fulfillment(of: [stopped], timeout: 3)
    }

    func testDefaultSessionStoresNoCookiesCredentialsOrCacheAndRefusesRedirects() async throws {
        let production = TranscriptionClient.makeEphemeralSession()
        defer { production.invalidateAndCancel() }
        XCTAssertNil(production.configuration.urlCache)
        XCTAssertNil(production.configuration.httpCookieStorage)
        XCTAssertNil(production.configuration.urlCredentialStorage)
        XCTAssertFalse(production.configuration.httpShouldSetCookies)
        let delegate = try XCTUnwrap(production.delegate as? NoRedirectSessionDelegate)
        let original = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        let target = URL(string: "https://example.com/steal")!
        let response = HTTPURLResponse(url: original, statusCode: 307, httpVersion: nil, headerFields: ["Location": target.absoluteString])!
        delegate.urlSession(production, task: production.dataTask(with: original), willPerformHTTPRedirection: response, newRequest: URLRequest(url: target)) { redirectedRequest in
            XCTAssertNil(redirectedRequest)
        }
    }

    private func assertError(_ expected: TranscriptionError, key: String = "test-key", options: TranscriptionOptions = .init(), file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await client.transcribe(fileURL: self.file, apiKey: key, options: options)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? TranscriptionError, expected, file: file, line: line)
        }
    }
}

private final class MockAudioURLProtocol: URLProtocol {
    static var handler: ((URLRequest, MockAudioURLProtocol) -> Void)?
    static var stopped: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        handler(request, self)
    }
    override func stopLoading() { Self.stopped?() }
    func respond(status: Int, body: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
