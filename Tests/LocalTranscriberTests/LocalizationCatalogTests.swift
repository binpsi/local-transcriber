import Foundation
import XCTest
import TranscriberCore
@testable import LocalTranscriber

final class LocalizationCatalogTests: XCTestCase {
    func testEveryTranscriptionErrorHasEnglishPresentationWithoutChangingCanonicalDescription() {
        let errors: [TranscriptionError] = [
            .invalidAPIKey, .unreadableFile, .emptyFile, .fileTooLarge,
            .unsupportedFileFormat, .invalidLanguages, .invalidKeywords, .invalidPrompt,
            .authenticationFailed, .permissionDenied, .modelUnavailable, .rateLimited,
            .quotaExceeded, .requestTooLarge, .serverUnavailable,
            .rejectedRequest(statusCode: 422), .unexpectedResponse, .emptyTranscription,
            .networkUnavailable, .requestTimedOut, .networkFailure, .redirectRefused,
        ]
        for error in errors {
            let canonical = error.localizedDescription
            let english = AppLocalization.text(canonical, language: .english)
            XCTAssertFalse(english.isEmpty)
            XCTAssertNotEqual(english, canonical, "Missing translation for \(error)")
            XCTAssertNil(english.range(of: #"\p{Han}"#, options: .regularExpression))
            XCTAssertEqual(AppLocalization.text(canonical, language: .chinese), canonical)
            XCTAssertEqual(error.localizedDescription, canonical)
        }
    }

    func testHTTPAndKeychainDiagnosticCodesArePreserved() {
        let rejection = TranscriptionError.rejectedRequest(statusCode: 422).localizedDescription
        XCTAssertTrue(AppLocalization.text(rejection, language: .english).contains("HTTP 422"))

        let operations = [("读取", "read"), ("保存", "save"), ("移除", "remove")]
        for (chinese, english) in operations {
            let message = "无法\(chinese)钥匙串中的 API Key（系统错误 -25308）。请确认登录钥匙串已解锁。"
            let translated = AppLocalization.text(message, language: .english)
            XCTAssertTrue(translated.contains("Could not \(english)"))
            XCTAssertTrue(translated.contains("system error -25308"))
            XCTAssertNil(translated.range(of: #"\p{Han}"#, options: .regularExpression))
        }
    }

    func testBackupFilenameIsPreservedVerbatimIncludingUnicodeAndFormatCharacters() {
        let filename = "history-damaged-中文-%@-100%.json"
        let message = "历史记录文件无法读取，原文件已保留为 \(filename)。可以继续保存新记录。"
        XCTAssertEqual(
            AppLocalization.text(message, language: .english),
            "The history file could not be read. The original was preserved as \(filename). You can continue saving new records."
        )
        XCTAssertEqual(AppLocalization.text(message, language: .chinese), message)
    }

    func testNestedRecordingWarningsTranslateTheirKnownDetails() {
        let retained = "录音失败：音频编码失败 已保留录音文件，可尝试转写。"
        XCTAssertEqual(
            AppLocalization.text(retained, language: .english),
            "Recording failed: Audio encoding failed. The recording has been retained; you can try transcribing it."
        )
        let lost = "录音意外结束。 未能恢复录音，请重新录制。"
        XCTAssertEqual(
            AppLocalization.text(lost, language: .english),
            "Recording ended unexpectedly. The recording could not be recovered. Record it again."
        )
    }

    func testUnknownSystemErrorDetailsRemainIntactInsideTranslatedWrappers() {
        XCTAssertEqual(AppLocalization.text("录音失败：", language: .english), "Recording failed.")
        XCTAssertEqual(AppLocalization.text("无法开始录音：", language: .english), "Could not start recording.")
        XCTAssertEqual(AppLocalization.text("音频转换失败。", language: .english), "Audio conversion failed.")
        let detail = "系统错误 -43: /Volumes/采访 100%/片段%@.m4a\nThe device is unavailable."
        XCTAssertEqual(AppLocalization.text(detail, language: .english), detail)
        XCTAssertEqual(
            AppLocalization.text("无法开始录音：" + detail, language: .english),
            "Could not start recording: " + detail
        )
        XCTAssertEqual(
            AppLocalization.text("音频转换失败。" + detail, language: .english),
            "Audio conversion failed. " + detail
        )
    }

    func testPreparationFallbackAndProgressRetainTheirNumbers() {
        XCTAssertEqual(
            AppLocalization.text("音频转换失败。请检查文件格式和可用磁盘空间。", language: .english),
            "Audio conversion failed. Check the file format and available disk space."
        )
        XCTAssertEqual(AppLocalization.text("正在准备第 12 段音频…", language: .english), "Preparing audio segment 12…")
        XCTAssertEqual(
            AppLocalization.text("音频已分为 21 段，将依次转写。", language: .english),
            "Audio split into 21 segments for sequential transcription."
        )
    }
}
