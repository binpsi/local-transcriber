import AppKit
import Combine
import UniformTypeIdentifiers
import XCTest
@testable import LocalTranscriber

final class AudioImportTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func mediaFile(in directory: URL, name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        // Import checks file metadata; decoding is performed before transcribing.
        try Data([1, 2, 3, 4]).write(to: url)
        return url
    }

    @MainActor
    func testRejectedFilesPreserveCurrentSourceAndUnsavedDraft() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory.appendingPathComponent("history"))
        let model = AppModel(history: history, loadAPIKey: false)
        let original = try mediaFile(in: directory, name: "原始录音.m4a")
        XCTAssertTrue(model.importAudio(from: [original]))
        model.draftTitle = "尚未保存的标题"
        model.draftText = "不能丢失的文字"
        let text = try mediaFile(in: directory, name: "document.txt")
        let empty = directory.appendingPathComponent("empty.mp3")
        try Data().write(to: empty)
        let invalidInputs: [[URL]] = [
            [], [original, original], [text], [empty], [directory],
            [directory.appendingPathComponent("missing.wav")],
            [URL(string: "https://example.com/audio.mp3")!]
        ]

        for input in invalidInputs {
            XCTAssertFalse(model.importAudio(from: input), "Should reject: \(input)")
            XCTAssertEqual(model.sourceURL, original)
            XCTAssertEqual(model.draftText, "不能丢失的文字")
            XCTAssertEqual(model.draftTitle, "尚未保存的标题")
            XCTAssertTrue(history.records.isEmpty, "Invalid imports must not save or reset the draft")
            XCTAssertNotNil(model.errorMessage)
        }
    }

    @MainActor
    func testValidImportSavesEditsAndAcceptsNativeMediaWithoutUploading() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = HistoryStore(directory: directory.appendingPathComponent("history"))
        let model = AppModel(history: history, loadAPIKey: false)
        model.draftTitle = "已校对的录音"
        model.draftText = "这是原有的校对结果"
        for name in ["访谈.AIFF", "录音.caf", "视频.mov", "recording.webm"] {
            let url = try mediaFile(in: directory, name: name)
            XCTAssertTrue(model.importAudio(from: [url]))
            XCTAssertEqual(model.sourceURL, url)
            XCTAssertEqual(model.sourceName, name)
            XCTAssertEqual(model.draftTitle, url.deletingPathExtension().lastPathComponent)
            XCTAssertTrue(model.draftText.isEmpty)
            XCTAssertTrue(model.canTranscribe)
            XCTAssertFalse(model.isWorking)
            XCTAssertFalse(model.showSettings)
        }
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.text, "这是原有的校对结果")
    }

    @MainActor
    func testFailedDraftSavePreventsReplacingAudio() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let historyDirectory = directory.appendingPathComponent("history")
        let history = HistoryStore(directory: historyDirectory)
        let model = AppModel(history: history, loadAPIKey: false)
        let first = try mediaFile(in: directory, name: "first.wav")
        let second = try mediaFile(in: directory, name: "second.mp3")
        XCTAssertTrue(model.importAudio(from: [first]))
        model.draftText = "必须保留的编辑"
        try FileManager.default.moveItem(at: historyDirectory, to: directory.appendingPathComponent("unavailable"))

        XCTAssertFalse(model.importAudio(from: [second]))
        XCTAssertEqual(model.sourceURL, first)
        XCTAssertEqual(model.draftText, "必须保留的编辑")
        XCTAssertNotNil(model.errorMessage)
    }

    @MainActor
    func testFileURLProviderImportsDataRepresentationAndBlocksNavigationWhileLoading() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(history: HistoryStore(directory: directory.appendingPathComponent("history")), loadAPIKey: false)
        let url = try mediaFile(in: directory, name: "中文 文件.m4a")
        let provider = DeferredFileProvider()
        model.draftText = "等待导入时保留"
        XCTAssertTrue(model.importDroppedAudio([provider]))
        XCTAssertTrue(model.isImportingAudio)
        XCTAssertTrue(model.isWorking)
        model.newTranscript()
        XCTAssertEqual(model.draftText, "等待导入时保留")
        XCTAssertFalse(model.importAudio(from: [url]))

        let imported = expectation(description: "File URL imported")
        let subscription = model.$sourceURL.sink { value in
            if value == url { imported.fulfill() }
        }
        provider.complete(with: url.dataRepresentation as NSData)
        await fulfillment(of: [imported], timeout: 2)
        withExtendedLifetime(subscription) {}
        XCTAssertFalse(model.isImportingAudio)
        XCTAssertEqual(model.sourceURL, url)
        XCTAssertEqual(model.history.records.first?.text, "等待导入时保留")
    }

    @MainActor
    func testNativeItemProviderImportsFinderStyleFileURL() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(history: HistoryStore(directory: directory.appendingPathComponent("history")), loadAPIKey: false)
        let url = try mediaFile(in: directory, name: "真实 provider 中文.wav")
        let provider = NSItemProvider(object: url as NSURL)
        let imported = expectation(description: "Native NSItemProvider resolved file URL")
        let subscription = model.$sourceURL.sink { value in
            if value == url { imported.fulfill() }
        }

        XCTAssertTrue(model.importDroppedAudio([provider]))
        await fulfillment(of: [imported], timeout: 3)
        withExtendedLifetime(subscription) {}
        XCTAssertEqual(model.sourceURL, url)
        XCTAssertFalse(model.isImportingAudio)
        XCTAssertTrue(model.canTranscribe)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testCancelledOrShutdownImportCannotReplaceLaterSource() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let staleURL = try mediaFile(in: directory, name: "stale.mp3")
        let laterURL = try mediaFile(in: directory, name: "later.m4a")
        for shouldShutdown in [false, true] {
            let model = AppModel(history: HistoryStore(directory: directory.appendingPathComponent(UUID().uuidString)), loadAPIKey: false)
            let provider = DeferredFileProvider()
            XCTAssertTrue(model.importDroppedAudio([provider]))
            if shouldShutdown {
                let result = await model.shutdown()
                XCTAssertTrue(result)
            } else {
                model.cancelAudioImport()
            }
            XCTAssertFalse(model.isImportingAudio)
            XCTAssertTrue(model.importAudio(from: [laterURL]))
            model.draftText = "后续编辑"

            let changed = expectation(description: "Stale callback must not change source")
            changed.isInverted = true
            let subscription = model.$sourceURL.dropFirst().sink { _ in changed.fulfill() }
            provider.complete(with: staleURL as NSURL)
            await fulfillment(of: [changed], timeout: 0.15)
            withExtendedLifetime(subscription) {}
            XCTAssertEqual(model.sourceURL, laterURL)
            XCTAssertEqual(model.draftText, "后续编辑")
        }
    }

    @MainActor
    func testDropRejectsMultipleFilesAndInvalidProviderBeforeResolving() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(history: HistoryStore(directory: directory), loadAPIKey: false)
        model.draftText = "保留草稿"
        XCTAssertFalse(model.importDroppedAudio([DeferredFileProvider(), DeferredFileProvider()]))
        XCTAssertFalse(model.importDroppedAudio([NSItemProvider()]))
        XCTAssertFalse(model.isImportingAudio)
        XCTAssertEqual(model.draftText, "保留草稿")
        XCTAssertTrue(model.history.records.isEmpty)
    }
}

private final class DeferredFileProvider: NSItemProvider {
    private var completion: NSItemProvider.CompletionHandler?

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        typeIdentifier == UTType.fileURL.identifier
    }

    override func loadItem(forTypeIdentifier typeIdentifier: String, options: [AnyHashable: Any]? = nil,
                           completionHandler: NSItemProvider.CompletionHandler? = nil) {
        completion = completionHandler
    }

    func complete(with item: NSSecureCoding) {
        completion?(item, nil)
        completion = nil
    }
}
