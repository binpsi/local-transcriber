import Combine
import Darwin
import Foundation
import Security

struct TranscriptRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var sourceName: String
    var model: String

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        createdAt: Date = Date(),
        sourceName: String,
        model: String = "gpt-transcribe"
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.sourceName = sourceName
        self.model = model
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [TranscriptRecord] = []
    @Published private(set) var errorMessage: String?

    private let directory: URL
    private let fileURL: URL
    private var writesBlocked = false
    private let maximumRecords = 100

    init(directory: URL? = nil) {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        self.directory = directory ?? supportDirectory
            .appendingPathComponent("LocalTranscriber", isDirectory: true)
        self.fileURL = self.directory.appendingPathComponent("history.json")
        loadHistory()
    }

    func save(_ record: TranscriptRecord) throws {
        var updated = records.filter { $0.id != record.id }
        updated.append(record)
        updated.sort { $0.createdAt > $1.createdAt }
        try persist(Array(updated.prefix(maximumRecords)))
    }

    func delete(id: UUID) throws {
        let updated = records.filter { $0.id != id }
        guard updated.count != records.count else { return }
        try persist(updated)
    }

    private func loadHistory() {
        let manager = FileManager.default
        do {
            try manager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: 0o700)]
            )
            try manager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: directory.path
            )
            guard manager.fileExists(atPath: fileURL.path) else { return }
            try manager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: fileURL.path
            )
            let data = try Data(contentsOf: fileURL)
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([TranscriptRecord].self, from: data)
                records = Array(decoded.sorted { $0.createdAt > $1.createdAt }
                    .prefix(maximumRecords))
            } catch {
                preserveCorruptHistory()
            }
        } catch {
            writesBlocked = true
            errorMessage = HistoryStorageError.unavailable.localizedDescription
        }
    }

    private func preserveCorruptHistory() {
        let backupName = "history-damaged-\(UUID().uuidString).json"
        let backupURL = directory.appendingPathComponent(backupName)
        do {
            // Only allow fresh writes after the original bytes are safely preserved.
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            errorMessage = "历史记录文件无法读取，原文件已保留为 \(backupName)。可以继续保存新记录。"
        } catch {
            writesBlocked = true
            errorMessage = HistoryStorageError.corruptFilePreservationFailed.localizedDescription
        }
    }

    private func persist(_ updated: [TranscriptRecord]) throws {
        guard !writesBlocked else {
            throw HistoryStorageError.writesBlocked
        }

        let temporaryURL = directory.appendingPathComponent(".history-\(UUID().uuidString).tmp")
        let manager = FileManager.default
        defer { try? manager.removeItem(at: temporaryURL) }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(updated)

            // The staging file is private from creation, and rename commits atomically.
            guard manager.createFile(
                atPath: temporaryURL.path,
                contents: nil,
                attributes: [.posixPermissions: NSNumber(value: 0o600)]
            ) else {
                throw HistoryStorageError.saveFailed
            }
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            guard Darwin.rename(temporaryURL.path, fileURL.path) == 0 else {
                throw HistoryStorageError.saveFailed
            }

            records = updated
            errorMessage = nil
        } catch {
            errorMessage = HistoryStorageError.saveFailed.localizedDescription
            throw HistoryStorageError.saveFailed
        }
    }
}

private enum HistoryStorageError: LocalizedError {
    case unavailable
    case corruptFilePreservationFailed
    case writesBlocked
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "无法访问本地历史记录。为保护已有记录，已暂停保存；请检查应用支持目录的访问权限后重新打开应用。"
        case .corruptFilePreservationFailed:
            return "历史记录文件损坏，且无法安全保留原文件。已暂停保存，原文件未被覆盖；请备份并检查历史记录目录后重新打开应用。"
        case .writesBlocked:
            return "本地历史记录当前不可写。已有文件会保留，请检查历史记录目录后重新打开应用。"
        case .saveFailed:
            return "无法保存本地历史记录。请检查磁盘空间和目录权限；已有记录未被覆盖。"
        }
    }
}

enum KeychainStore {
    private static let service = "com.localtranscriber.mac"
    private static let account = "openai-api-key"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }

    static func load() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainStorageError.operationFailed("读取", status)
        }
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            throw KeychainStorageError.invalidStoredValue
        }
        return key
    }

    static func save(_ key: String) throws {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw KeychainStorageError.emptyKey }
        let data = Data(cleaned.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]

        // A failed update leaves an existing credential intact.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "Local Transcriber — OpenAI API Key"
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            }
        }
        guard status == errSecSuccess else {
            throw KeychainStorageError.operationFailed("保存", status)
        }
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStorageError.operationFailed("移除", status)
        }
    }
}

private enum KeychainStorageError: LocalizedError {
    case emptyKey
    case invalidStoredValue
    case operationFailed(String, OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "请输入 OpenAI API Key。"
        case .invalidStoredValue:
            return "钥匙串中的 API Key 无法读取，请重新保存。"
        case let .operationFailed(operation, status):
            return "无法\(operation)钥匙串中的 API Key（系统错误 \(status)）。请确认登录钥匙串已解锁。"
        }
    }
}
