import Foundation
import XCTest
@testable import LocalTranscriber

final class LocalizationStateTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalizationStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testLanguageResolutionRespectsExplicitChoiceAndSystemFallback() {
        XCTAssertEqual(AppLanguage.resolve(savedValue: "en", preferredLanguages: ["zh-Hans-CN"]), .english)
        XCTAssertEqual(AppLanguage.resolve(savedValue: "zh-Hans", preferredLanguages: ["en-US"]), .chinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["zh-Hant-TW"]), .chinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: "invalid", preferredLanguages: ["zh-CN"]), .chinese)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["en-GB"]), .english)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolve(savedValue: nil, preferredLanguages: []), .english)
    }

    @MainActor
    func testInterfaceChoicePersistsAndOverridesSystemAfterRelaunch() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalizationStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(history: HistoryStore(directory: directory), loadAPIKey: false,
                             defaults: defaults, preferredLanguages: ["zh-Hans-CN"])
        XCTAssertEqual(model.interfaceLanguage, .chinese)
        model.interfaceLanguage = .english
        XCTAssertEqual(defaults.string(forKey: "interfaceLanguage"), "en")

        let reloaded = AppModel(history: HistoryStore(directory: directory), loadAPIKey: false,
                                defaults: defaults, preferredLanguages: ["zh-Hans-CN"])
        XCTAssertEqual(reloaded.interfaceLanguage, .english)
        XCTAssertEqual(reloaded.t(reloaded.status), "Ready")
        reloaded.interfaceLanguage = .chinese
        XCTAssertEqual(defaults.string(forKey: "interfaceLanguage"), "zh-Hans")
    }

    @MainActor
    func testSwitchingInterfacePreservesUnsavedDraftHistoryAndTranscriptionHints() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalizationStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(LanguageHint.bilingual.rawValue, forKey: "languageHint")
        defaults.set("Dr. 陈, OpenAI", forKey: "transcriptionKeywords")
        defaults.set("中英双语访谈", forKey: "transcriptionContext")
        let history = HistoryStore(directory: directory)
        let record = TranscriptRecord(title: "新的转写", text: "原文 Original", sourceName: "麦克风录音")
        try history.save(record)
        let model = AppModel(history: history, loadAPIKey: false, defaults: defaults,
                             preferredLanguages: ["zh-Hans"])
        model.selectRecord(record)
        model.draftTitle = "用户编辑 · Custom title"
        model.draftText = "未保存的内容 / Unsaved content"
        let beforeHistory = history.records

        for language in [AppLanguage.english, .chinese, .english] {
            model.interfaceLanguage = language
            XCTAssertEqual(model.draftTitle, "用户编辑 · Custom title")
            XCTAssertEqual(model.draftText, "未保存的内容 / Unsaved content")
            XCTAssertEqual(model.selectedRecordID, record.id)
            XCTAssertEqual(history.records, beforeHistory)
            XCTAssertEqual(HistoryStore(directory: directory).records, beforeHistory)
            XCTAssertTrue(model.hasEdits)
            XCTAssertEqual(model.language, .bilingual)
            XCTAssertEqual(model.language.codes, ["zh", "en"])
            XCTAssertEqual(model.keywords, "Dr. 陈, OpenAI")
            XCTAssertEqual(model.context, "中英双语访谈")
            XCTAssertEqual(defaults.string(forKey: "languageHint"), "中文 + English")
            XCTAssertFalse(model.hasAPIKey)
        }
    }

    @MainActor
    func testLanguageSwitchDoesNotTranslateImportedFilenameOrTitle() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalizationStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(history: HistoryStore(directory: directory.appendingPathComponent("history")),
                             loadAPIKey: false, defaults: defaults, preferredLanguages: ["zh-Hans"])
        // The basename intentionally matches a localized UI string.
        let file = directory.appendingPathComponent("新的转写.wav")
        try Data([1, 2, 3, 4]).write(to: file)
        XCTAssertTrue(model.importAudio(from: [file]))

        model.interfaceLanguage = .english
        XCTAssertEqual(model.sourceURL, file)
        XCTAssertEqual(model.displaySourceName, "新的转写.wav")
        XCTAssertEqual(model.sourceName, "新的转写.wav")
        XCTAssertEqual(model.draftTitle, "新的转写")
        XCTAssertEqual(model.t(model.status), "Audio ready")
        XCTAssertEqual(model.status, "音频已就绪")
        XCTAssertTrue(model.history.records.isEmpty)
    }

    @MainActor
    func testAlreadyVisibleNoticesAndErrorsSwitchWithoutRewritingStoredMessages() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalizationStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(history: HistoryStore(directory: directory), loadAPIKey: false,
                             defaults: defaults, preferredLanguages: ["zh-Hans"])
        model.notice = "已复制文字"
        model.errorMessage = "请输入完整的 API Key，不能包含空格。"
        XCTAssertEqual(model.t(try XCTUnwrap(model.notice)), "已复制文字")
        model.interfaceLanguage = .english
        XCTAssertEqual(model.t(try XCTUnwrap(model.notice)), "Text copied")
        XCTAssertEqual(model.t(try XCTUnwrap(model.errorMessage)), "Enter a complete API key without spaces.")
        XCTAssertEqual(model.t("正在转写第 2 / 12 段…"), "Transcribing segment 2 of 12…")
        XCTAssertEqual(model.format("录音 · %@", "October 26, 2026"), "Recording · October 26, 2026")
        model.interfaceLanguage = .chinese
        XCTAssertEqual(model.t(try XCTUnwrap(model.notice)), "已复制文字")
        XCTAssertEqual(model.notice, "已复制文字")
        XCTAssertEqual(model.errorMessage, "请输入完整的 API Key，不能包含空格。")
    }

    @MainActor
    func testOnlyNewGeneratedTitlesUseNewInterfaceLanguage() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalizationStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = HistoryStore(directory: directory)
        let model = AppModel(history: history, loadAPIKey: false, defaults: defaults,
                             preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(model.draftTitle, "新的转写")
        model.interfaceLanguage = .english
        XCTAssertEqual(model.draftTitle, "新的转写", "Changing language must not rewrite a draft title")
        model.newTranscript()
        XCTAssertEqual(model.draftTitle, "New transcript")
        model.draftTitle = ""
        model.draftText = "保留原文"
        XCTAssertTrue(model.saveEdits())
        XCTAssertEqual(history.records.first?.title, "Untitled transcript")
        XCTAssertEqual(history.records.first?.text, "保留原文")
    }

    func testTranscriptionLanguageCodesAreIndependentOfDisplayLanguage() {
        let expectations: [(LanguageHint, String, [String])] = [
            (.auto, "Auto-detect", []),
            (.chinese, "Mandarin Chinese", ["zh"]),
            (.bilingual, "Chinese + English", ["zh", "en"]),
            (.english, "English", ["en"]),
            (.cantonese, "Cantonese", ["yue"]),
            (.japanese, "Japanese", ["ja"]),
        ]
        for (hint, englishName, codes) in expectations {
            XCTAssertEqual(hint.displayName(in: .chinese), hint.rawValue)
            XCTAssertEqual(hint.displayName(in: .english), englishName)
            XCTAssertEqual(hint.codes, codes)
            XCTAssertEqual(LanguageHint(rawValue: hint.rawValue), hint)
        }
    }
}
