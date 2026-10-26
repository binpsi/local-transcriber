import Foundation

/// Accuracy hints accepted by the transcription API. Empty hints use automatic detection.
public struct TranscriptionOptions: Sendable, Equatable {
    public static let model = "gpt-transcribe"

    // These conservative local limits keep requests small; they are not API quotas.
    public static let maximumLanguages = 5
    public static let maximumKeywords = 100
    public static let maximumKeywordCharacters = 100
    public static let maximumPromptCharacters = 4_000

    public var languages: [String]
    public var keywords: [String]
    public var prompt: String

    public init(languages: [String] = [], keywords: [String] = [], prompt: String = "") {
        self.languages = languages
        self.keywords = keywords
        self.prompt = prompt
    }

    fileprivate func validated() throws -> TranscriptionOptions {
        let languages = Self.unique(languages.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        guard languages.count <= Self.maximumLanguages,
              languages.allSatisfy({ value in
                  // Accept the documented code shapes; the API decides which languages are supported.
                  value.range(of: #"^[a-z]{2,3}(-[a-z]{2})?$"#, options: .regularExpression) != nil
              }) else {
            throw TranscriptionError.invalidLanguages
        }

        let forbiddenKeywordCharacters = CharacterSet(charactersIn: "<>\r\n\0")
        guard keywords.allSatisfy({ $0.rangeOfCharacter(from: forbiddenKeywordCharacters) == nil }) else {
            throw TranscriptionError.invalidKeywords
        }
        let keywords = Self.unique(keywords.map { $0.trimmingCharacters(in: .whitespaces) })
        guard keywords.count <= Self.maximumKeywords,
              keywords.allSatisfy({ $0.count <= Self.maximumKeywordCharacters }) else {
            throw TranscriptionError.invalidKeywords
        }
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.count <= Self.maximumPromptCharacters, !prompt.contains("\0") else {
            throw TranscriptionError.invalidPrompt
        }
        return TranscriptionOptions(languages: languages, keywords: keywords, prompt: prompt)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

public enum TranscriptionError: LocalizedError, Equatable {
    case invalidAPIKey
    case unreadableFile
    case emptyFile
    case fileTooLarge
    case unsupportedFileFormat
    case invalidLanguages
    case invalidKeywords
    case invalidPrompt
    case authenticationFailed
    case permissionDenied
    case modelUnavailable
    case rateLimited
    case quotaExceeded
    case requestTooLarge
    case serverUnavailable
    case rejectedRequest(statusCode: Int)
    case unexpectedResponse
    case emptyTranscription
    case networkUnavailable
    case requestTimedOut
    case networkFailure
    case redirectRefused

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "请填写有效的 OpenAI API Key，密钥中不能含有空格或换行。"
        case .unreadableFile: return "无法读取音频文件，请确认文件仍然存在且可以访问。"
        case .emptyFile: return "音频文件为空，请重新录音或选择其他文件。"
        case .fileTooLarge: return "音频超过本软件的 24 MB 限制，请缩短录音或选择较小的文件。"
        case .unsupportedFileFormat: return "不支持此音频格式。请选择 M4A、MP3、WAV、FLAC、MP4、MPEG、MPGA、OGG 或 WebM。"
        case .invalidLanguages: return "语言提示最多填写 5 个语言代码，例如 zh、en、yue 或 zh-cn。"
        case .invalidKeywords: return "关键词最多 100 个，每个最多 100 个字符，且不能含换行、<、> 或空字符。"
        case .invalidPrompt: return "转写说明最多 4,000 个字符，且不能含空字符。"
        case .authenticationFailed: return "API Key 无效或已过期，请在设置中更新密钥。"
        case .permissionDenied: return "此 API Key 或项目没有转写权限，请检查 OpenAI 项目权限和地区可用性。"
        case .modelUnavailable: return "当前项目无法使用 gpt-transcribe，请检查该模型的访问权限。"
        case .rateLimited: return "请求过于频繁，请稍后重试或检查 OpenAI 项目的速率限制。"
        case .quotaExceeded: return "OpenAI API 额度不足，请检查 API 账户余额和项目预算。ChatGPT 订阅不包含 API 额度。"
        case .requestTooLarge: return "OpenAI 拒绝了过大的音频，请缩短录音或选择较小的文件。"
        case .serverUnavailable: return "OpenAI 服务暂时不可用，请稍后重试。"
        case .rejectedRequest(let statusCode): return "转写请求未被接受（HTTP \(statusCode)），请检查音频是否有效以及转写提示是否合适。"
        case .unexpectedResponse: return "OpenAI 返回了无法识别的结果，请稍后重试。"
        case .emptyTranscription: return "没有识别到文字，请确认音频中有清晰的人声。"
        case .networkUnavailable: return "无法连接 OpenAI，请检查网络连接或代理设置。"
        case .requestTimedOut: return "转写请求超时，请检查网络或使用较短的音频重试。"
        case .networkFailure: return "转写连接中断，请检查网络后重试。"
        case .redirectRefused: return "服务器要求重定向；为保护 API Key，已停止请求。"
        }
    }
}

/// Sends audio directly to the fixed OpenAI endpoint without retaining transcripts or credentials.
public actor TranscriptionClient {
    public static let maximumFileBytes = 24_000_000
    public static let model = TranscriptionOptions.model
    public static let supportedFileExtensions = ["flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "wav", "webm"]

    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let session: URLSession

    /// An injected session is intended for tests. Production uses an ephemeral, redirect-blocking session.
    public init(session: URLSession = TranscriptionClient.makeEphemeralSession()) {
        self.session = session
    }

    public static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 900
        return URLSession(configuration: configuration, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)
    }

    public func transcribe(fileURL: URL, apiKey: String, options: TranscriptionOptions = .init()) async throws -> String {
        try Task.checkCancellation()
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.count <= 4_096,
              key.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw TranscriptionError.invalidAPIKey
        }
        let options = try options.validated()
        let boundary = "LocalTranscriber-\(UUID().uuidString)"
        let multipart = try makeMultipartFile(fileURL: fileURL, options: options, boundary: boundary)
        defer { try? FileManager.default.removeItem(at: multipart.deletingLastPathComponent()) }
        try Task.checkCancellation()

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: multipart)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            switch (error as? URLError)?.code {
            case .timedOut: throw TranscriptionError.requestTimedOut
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                throw TranscriptionError.networkUnavailable
            default: throw TranscriptionError.networkFailure
            }
        }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw TranscriptionError.unexpectedResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw Self.error(for: response.statusCode, data: data)
        }
        guard let result = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw TranscriptionError.unexpectedResponse
        }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriptionError.emptyTranscription }
        return text
    }

    // Stream at most 24 MB to a private temporary file. The original filename/path is never sent.
    // Internal visibility allows tests to verify multipart framing without a live network request.
    func makeMultipartFile(fileURL: URL, options: TranscriptionOptions, boundary: String) throws -> URL {
        guard fileURL.isFileURL else { throw TranscriptionError.unreadableFile }
        let fileExtension = fileURL.pathExtension.lowercased()
        guard let contentType = Self.mimeTypes[fileExtension] else { throw TranscriptionError.unsupportedFileFormat }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("local-transcriber-upload-\(UUID().uuidString)", isDirectory: true)
        let destination = directory.appendingPathComponent("request.multipart")
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: directory) } }

        do {
            // URL resource values may be cached across retries; always inspect the current file.
            let properties = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard properties[.type] as? FileAttributeType == .typeRegular,
                  let size = properties[.size] as? NSNumber else { throw TranscriptionError.unreadableFile }
            guard size.int64Value > 0 else { throw TranscriptionError.emptyFile }
            guard size.int64Value <= Int64(Self.maximumFileBytes) else { throw TranscriptionError.fileTooLarge }
            let input = try FileHandle(forReadingFrom: fileURL)
            defer { try? input.close() }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            guard FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw TranscriptionError.unreadableFile
            }
            let output = try FileHandle(forWritingTo: destination)
            defer { try? output.close() }
            func write(_ string: String) throws { try output.write(contentsOf: Data(string.utf8)) }
            func field(_ name: String, _ value: String) throws {
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
            }
            try field("model", Self.model)
            try field("response_format", "json")
            for language in options.languages { try field("languages[]", language) }
            for keyword in options.keywords { try field("keywords[]", keyword) }
            if !options.prompt.isEmpty { try field("prompt", options.prompt) }
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.\(fileExtension)\"\r\nContent-Type: \(contentType)\r\n\r\n")

            var copied = 0
            while let chunk = try input.read(upToCount: 64 * 1_024), !chunk.isEmpty {
                try Task.checkCancellation()
                copied += chunk.count
                guard copied <= Self.maximumFileBytes else { throw TranscriptionError.fileTooLarge }
                try output.write(contentsOf: chunk)
            }
            guard copied > 0 else { throw TranscriptionError.emptyFile }
            try write("\r\n--\(boundary)--\r\n")
            try output.synchronize()
            succeeded = true
            return destination
        } catch let error as TranscriptionError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TranscriptionError.unreadableFile
        }
    }

    private static func error(for statusCode: Int, data: Data) -> TranscriptionError {
        switch statusCode {
        case 300...399: return .redirectRefused
        case 401: return .authenticationFailed
        case 403: return .permissionDenied
        case 404: return .modelUnavailable
        case 413: return .requestTooLarge
        case 429:
            // Read only machine-readable categories, never expose a raw server message.
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let quotaCodes = ["insufficient_quota", "billing_hard_limit_reached", "billing_not_active"]
            if quotaCodes.contains(payload?.error.code ?? "") || quotaCodes.contains(payload?.error.type ?? "") {
                return .quotaExceeded
            }
            return .rateLimited
        case 500...599: return .serverUnavailable
        default: return .rejectedRequest(statusCode: statusCode)
        }
    }

    private static let mimeTypes = [
        "flac": "audio/flac", "mp3": "audio/mpeg", "mp4": "audio/mp4",
        "mpeg": "audio/mpeg", "mpga": "audio/mpeg", "m4a": "audio/mp4",
        "ogg": "audio/ogg", "wav": "audio/wav", "webm": "audio/webm"
    ]

    private struct TranscriptionResponse: Decodable { let text: String }
    private struct APIErrorResponse: Decodable {
        let error: Details
        struct Details: Decodable { let code: String?; let type: String? }
    }
}

final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
