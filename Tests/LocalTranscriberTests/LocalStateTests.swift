import Foundation
import XCTest
@testable import LocalTranscriber

final class LocalStateTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalTranscriberTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    func testPendingDraftSavesWithNilOrNotYetPersistedIdentifier() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        for pendingID: UUID? in [nil, UUID()] {
            let location = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let history = HistoryStore(directory: location)
            let model = AppModel(history: history, loadAPIKey: false)
            model.selectedRecordID = pendingID
            model.draftTitle = "尚未完成的访谈"
            model.draftText = "这段已识别的文字尚未写入磁盘。"

            XCTAssertTrue(model.hasEdits)
            XCTAssertTrue(model.saveEdits())
            let saved = try XCTUnwrap(history.records.first)
            XCTAssertEqual(saved.text, model.draftText)
            XCTAssertEqual(saved.title, model.draftTitle)
            XCTAssertEqual(saved.id, model.selectedRecordID)
            if let pendingID { XCTAssertEqual(saved.id, pendingID) }
            XCTAssertFalse(model.hasEdits)
            XCTAssertEqual(HistoryStore(directory: location).records, [saved])
        }
    }

    @MainActor
    func testFailedSavePreventsNewDraftAndSelectionUntilStorageRecovers() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = directory.appendingPathComponent("history", isDirectory: true)
        let moved = directory.appendingPathComponent("history-unavailable", isDirectory: true)
        let history = HistoryStore(directory: location)
        let old = TranscriptRecord(title: "已有记录", text: "旧文字", sourceName: "old.m4a")
        try history.save(old)
        let model = AppModel(history: history, loadAPIKey: false)
        model.draftTitle = "待保存"
        model.draftText = "唯一一份尚未保存的转写。"
        try FileManager.default.moveItem(at: location, to: moved)

        model.newTranscript()
        XCTAssertEqual(model.draftText, "唯一一份尚未保存的转写。")
        XCTAssertEqual(model.draftTitle, "待保存")
        XCTAssertNil(model.selectedRecordID)
        XCTAssertNotNil(model.errorMessage)
        model.selectRecord(old)
        XCTAssertEqual(model.draftText, "唯一一份尚未保存的转写。")
        XCTAssertNil(model.selectedRecordID)
        XCTAssertEqual(history.records, [old])

        try FileManager.default.moveItem(at: moved, to: location)
        model.newTranscript()
        XCTAssertTrue(model.draftText.isEmpty)
        XCTAssertNil(model.selectedRecordID)
        XCTAssertTrue(HistoryStore(directory: location).records.contains {
            $0.text == "唯一一份尚未保存的转写。" && $0.title == "待保存"
        })
    }

    @MainActor
    func testClickingSelectedRecordDoesNotRevertUnsavedEdits() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory)
        let original = TranscriptRecord(title: "原始标题", text: "原始文字", sourceName: "interview.m4a")
        try history.save(original)
        let model = AppModel(history: history, loadAPIKey: false)
        model.selectRecord(original)
        model.draftText = "用户已校对的文字"
        model.draftTitle = "已校对"

        // A sidebar button can still hold the value from before the edit.
        model.selectRecord(original)

        XCTAssertEqual(model.draftText, "用户已校对的文字")
        XCTAssertEqual(model.draftTitle, "已校对")
        XCTAssertTrue(model.hasEdits)
        XCTAssertTrue(model.saveEdits())
        XCTAssertEqual(HistoryStore(directory: directory).records.first?.text, "用户已校对的文字")
    }

    @MainActor
    func testSwitchingRecordsPersistsEditsAndPreservesRecordMetadata() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory)
        let first = TranscriptRecord(title: "第一段", text: "原文字", sourceName: "first.wav", model: "original-model")
        let second = TranscriptRecord(title: "第二段", text: "第二段文字", sourceName: "second.wav")
        try history.save(first)
        try history.save(second)
        let model = AppModel(history: history, loadAPIKey: false)
        model.selectRecord(first)
        model.draftText = "第一段的校对结果"
        model.draftTitle = "校对完成"

        model.selectRecord(second)

        XCTAssertEqual(model.selectedRecordID, second.id)
        XCTAssertEqual(model.draftText, second.text)
        let updated = try XCTUnwrap(HistoryStore(directory: directory).records.first { $0.id == first.id })
        XCTAssertEqual(updated.text, "第一段的校对结果")
        XCTAssertEqual(updated.title, "校对完成")
        XCTAssertEqual(updated.createdAt, first.createdAt)
        XCTAssertEqual(updated.sourceName, first.sourceName)
        XCTAssertEqual(updated.model, first.model)
    }

    @MainActor
    func testShutdownRefusesToLosePendingDraftAndCanRetryAfterStorageRecovery() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = directory.appendingPathComponent("history", isDirectory: true)
        let moved = directory.appendingPathComponent("history-unavailable", isDirectory: true)
        let history = HistoryStore(directory: location)
        let model = AppModel(history: history, loadAPIKey: false)
        model.draftText = "退出前必须保存的文字"
        try FileManager.default.moveItem(at: location, to: moved)

        let failedShutdown = await model.shutdown()
        XCTAssertFalse(failedShutdown)
        XCTAssertFalse(model.isTerminating)
        XCTAssertEqual(model.draftText, "退出前必须保存的文字")

        try FileManager.default.moveItem(at: moved, to: location)
        let successfulShutdown = await model.shutdown()
        XCTAssertTrue(successfulShutdown)
        XCTAssertEqual(HistoryStore(directory: location).records.first?.text, "退出前必须保存的文字")
    }

    @MainActor
    func testHistoryRoundtripUpdateDeleteAndPrivatePermissions() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory)
        let record = TranscriptRecord(title: "中文标题", text: "中文与 English。\n第二行", sourceName: "source.m4a")
        try history.save(record)
        XCTAssertEqual(HistoryStore(directory: directory).records, [record])

        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("history.json").path)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)

        var edited = record
        edited.text = "更新后的内容"
        try history.save(edited)
        XCTAssertEqual(HistoryStore(directory: directory).records, [edited])
        try history.delete(id: record.id)
        XCTAssertTrue(HistoryStore(directory: directory).records.isEmpty)
    }

    @MainActor
    func testHistoryRetainsTheNewest100RecordsAcrossLaunches() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory)
        var records: [TranscriptRecord] = []
        for index in 0..<103 {
            let record = TranscriptRecord(title: "\(index)", text: "文字 \(index)",
                                          createdAt: Date(timeIntervalSinceReferenceDate: Double(index)), sourceName: "audio")
            records.append(record)
            try history.save(record)
        }
        let expected = Array(records.suffix(100).reversed())
        XCTAssertEqual(history.records, expected)
        XCTAssertEqual(HistoryStore(directory: directory).records, expected)
    }

    @MainActor
    func testFailedHistoryWritePreservesMemoryAndPreviouslyCommittedBytes() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let location = directory.appendingPathComponent("history", isDirectory: true)
        let moved = directory.appendingPathComponent("history-unavailable", isDirectory: true)
        let history = HistoryStore(directory: location)
        let record = TranscriptRecord(title: "已保存", text: "必须保留", sourceName: "audio")
        try history.save(record)
        let committedBytes = try Data(contentsOf: location.appendingPathComponent("history.json"))
        try FileManager.default.moveItem(at: location, to: moved)

        XCTAssertThrowsError(try history.save(TranscriptRecord(title: "新记录", text: "无法写入", sourceName: "audio")))

        XCTAssertEqual(history.records, [record])
        XCTAssertNotNil(history.errorMessage)
        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("history.json")), committedBytes)
        XCTAssertEqual(HistoryStore(directory: moved).records, [record])
    }

    @MainActor
    func testCorruptHistoryIsPreservedBeforeSavingFreshRecords() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let damagedBytes = Data("{ damaged history with recoverable text".utf8)
        try damagedBytes.write(to: directory.appendingPathComponent("history.json"))
        let history = HistoryStore(directory: directory)
        XCTAssertTrue(history.records.isEmpty)
        XCTAssertNotNil(history.errorMessage)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let backup = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("history-damaged-") })
        XCTAssertEqual(try Data(contentsOf: backup), damagedBytes)

        let record = TranscriptRecord(title: "恢复后", text: "新的文字", sourceName: "audio")
        try history.save(record)

        XCTAssertEqual(try Data(contentsOf: backup), damagedBytes)
        XCTAssertEqual(HistoryStore(directory: directory).records, [record])
    }
}
