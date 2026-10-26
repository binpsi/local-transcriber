import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TranscriberCore

enum LanguageHint: String, CaseIterable, Identifiable {
    case auto = "自动识别", chinese = "普通话", bilingual = "中文 + English", english = "English", cantonese = "粤语", japanese = "日本語"
    var id: String { rawValue }
    func displayName(in language: AppLanguage) -> String {
        AppLocalization.text(rawValue, language: language)
    }
    var codes: [String] {
        switch self {
        case .auto: return []
        case .chinese: return ["zh"]
        case .bilingual: return ["zh", "en"]
        case .english: return ["en"]
        case .cantonese: return ["yue"]
        case .japanese: return ["ja"]
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let recorder = AudioRecorder()
    let history: HistoryStore
    private let defaults: UserDefaults
    @Published var interfaceLanguage: AppLanguage {
        didSet { defaults.set(interfaceLanguage.rawValue, forKey: "interfaceLanguage") }
    }
    @Published var showSettings = false
    @Published private(set) var hasAPIKey = false
    @Published var selectedRecordID: UUID?
    @Published var draftText = ""
    @Published var draftTitle = "新的转写"
    @Published private(set) var sourceURL: URL?
    @Published private(set) var sourceName = ""
    @Published private(set) var isBusy = false
    @Published private(set) var isStartingRecording = false
    @Published private(set) var isImportingAudio = false
    @Published private(set) var isTerminating = false
    @Published private(set) var progress = 0.0
    @Published private(set) var status = "准备就绪"
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var language: LanguageHint {
        didSet { defaults.set(language.rawValue, forKey: "languageHint") }
    }
    @Published var context: String {
        didSet { defaults.set(context, forKey: "transcriptionContext") }
    }
    @Published var keywords: String {
        didSet { defaults.set(keywords, forKey: "transcriptionKeywords") }
    }
    private var apiKey = ""
    private var ownedRecording: URL?
    private var operation: Task<Void, Never>?
    private var activeOperationID: UUID?
    private var pendingImportID: UUID?
    private var draftCreatedAt = Date()
    private let client = TranscriptionClient()

    var isWorking: Bool { isBusy || isStartingRecording || isImportingAudio || recorder.isRecording || isTerminating }
    var canTranscribe: Bool { sourceURL != nil && !isWorking }
    // Only app-owned microphone labels are localized. Imported filenames and
    // saved transcript content remain exactly as supplied by the user.
    var displaySourceName: String { ownedRecording == nil ? sourceName : t(sourceName) }
    var hasEdits: Bool {
        guard let record = history.records.first(where: { $0.id == selectedRecordID }) else { return !draftText.isEmpty }
        return record.text != draftText || record.title != draftTitle
    }

    init(history: HistoryStore? = nil, loadAPIKey: Bool = true,
         defaults: UserDefaults = .standard, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        self.history = history ?? HistoryStore()
        interfaceLanguage = AppLanguage.resolve(savedValue: defaults.string(forKey: "interfaceLanguage"),
                                                preferredLanguages: preferredLanguages)
        language = LanguageHint(rawValue: defaults.string(forKey: "languageHint") ?? "") ?? .auto
        context = defaults.string(forKey: "transcriptionContext") ?? ""
        keywords = defaults.string(forKey: "transcriptionKeywords") ?? ""
        draftTitle = AppLocalization.text("新的转写", language: interfaceLanguage)
        guard loadAPIKey else { return }
        do {
            apiKey = try KeychainStore.load() ?? ""
            hasAPIKey = !apiKey.isEmpty
        } catch { errorMessage = error.localizedDescription }
    }

    func t(_ canonicalChinese: String) -> String {
        AppLocalization.text(canonicalChinese, language: interfaceLanguage)
    }

    func format(_ canonicalChineseFormat: String, _ arguments: CVarArg...) -> String {
        AppLocalization.formatted(canonicalChineseFormat, language: interfaceLanguage, arguments: arguments)
    }

    func saveAPIKey(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains(where: { $0.isWhitespace }) else {
            throw UserFacingError("请输入完整的 API Key，不能包含空格。")
        }
        try KeychainStore.save(key)
        apiKey = key
        hasAPIKey = true
        notice = "API Key 已安全保存到钥匙串"
    }

    func removeAPIKey() throws {
        try KeychainStore.delete()
        apiKey = ""
        hasAPIKey = false
    }

    func importAudio() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.title = t("选择要转写的音频")
        panel.prompt = t("导入")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = AudioImport.allowedContentTypes
        guard panel.runModal() == .OK else { return }
        importAudio(from: panel.urls)
    }

    @discardableResult
    func importAudio(from urls: [URL]) -> Bool {
        guard !isWorking else { return false }
        let url: URL
        do {
            // Validate before saving or clearing the current draft. A rejected
            // drop must leave both the current text and source available.
            url = try AudioImport.validate(urls)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        guard saveEdits() else { return false }
        resetDraft()
        sourceURL = url
        sourceName = url.lastPathComponent
        draftTitle = url.deletingPathExtension().lastPathComponent
        status = "音频已就绪"
        return true
    }

    @discardableResult
    func importDroppedAudio(_ providers: [NSItemProvider]) -> Bool {
        guard !isWorking else { return false }
        guard providers.count == 1 else {
            errorMessage = "请一次导入一个音频或视频文件。"
            return false
        }
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            errorMessage = "请从 Finder 拖入本机的音频或视频文件。"
            return false
        }
        let importID = UUID()
        pendingImportID = importID
        isImportingAudio = true
        errorMessage = nil
        notice = nil
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            // Resolve only the file URL, never a temporary file representation
            // whose lifetime could end when this provider callback returns.
            let url = AudioImport.fileURL(from: item)
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.pendingImportID == importID, !self.isTerminating else { return }
                self.pendingImportID = nil
                self.isImportingAudio = false
                guard !failed, let url else {
                    self.errorMessage = "无法读取拖入的文件，请从 Finder 重试，或点击选择文件。"
                    return
                }
                self.importAudio(from: [url])
            }
        }
        return true
    }

    func toggleRecording() {
        if recorder.isRecording {
            guard let url = recorder.stop() else {
                errorMessage = recorder.errorMessage ?? "录音未能保存，请重试。"
                return
            }
            ownedRecording = url
            sourceURL = url
            sourceName = "麦克风录音"
            transcribe()
            return
        }
        guard !isWorking else { return }
        guard hasAPIKey else { showSettings = true; return }
        guard saveEdits() else { return }
        resetDraft()
        isStartingRecording = true
        operation = Task { [weak self] in
            guard let self else { return }
            defer { self.isStartingRecording = false; self.operation = nil }
            do {
                try await self.recorder.start()
                self.status = "正在录音"
                let timestamp = Date().formatted(.dateTime.locale(self.interfaceLanguage.locale))
                self.draftTitle = self.format("录音 · %@", timestamp)
            } catch {
                self.errorMessage = error.localizedDescription
                self.status = "录音未开始"
            }
        }
    }

    func discardRecording() {
        recorder.discard()
        status = "录音已取消"
    }

    func recoverRecording() {
        guard let url = recorder.takeRecoveredRecording() else { return }
        ownedRecording = url
        sourceURL = url
        sourceName = "恢复的麦克风录音"
        status = "已保留中断前的录音"
        notice = "可以点击“转写音频”处理已保留的录音。"
    }

    func transcribe() {
        guard let url = sourceURL, !isWorking else { return }
        guard hasAPIKey else { showSettings = true; return }
        guard saveEdits() else { return }
        let key = apiKey
        let terms = keywords.components(separatedBy: CharacterSet(charactersIn: ",，\n;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let options = TranscriptionOptions(languages: language.codes, keywords: terms, prompt: context.trimmingCharacters(in: .whitespacesAndNewlines))
        // Each retry gets a new record. A failed retry must never overwrite a
        // previously saved partial transcript with an empty or shorter result.
        let recordID = UUID()
        let title = ["（未完成）", " (Incomplete)"].reduce(draftTitle) { value, suffix in
            value.hasSuffix(suffix) ? String(value.dropLast(suffix.count)) : value
        }
        let name = sourceName
        let operationID = UUID()
        activeOperationID = operationID
        selectedRecordID = recordID
        draftCreatedAt = Date()
        draftTitle = title + t("（未完成）")
        errorMessage = nil
        notice = nil
        isBusy = true
        progress = 0
        draftText = ""
        status = "正在准备音频…"
        operation = Task { [weak self] in
            guard let self else { return }
            var partial = ""
            defer { self.isBusy = false; self.operation = nil; self.activeOperationID = nil }
            do {
                let prepared = try await AudioPreparation.prepare(url: url) { [weak self] message in
                    Task { @MainActor in
                        if self?.activeOperationID == operationID && self?.progress == 0 { self?.status = message }
                    }
                }
                defer { prepared.cleanup() }
                try Task.checkCancellation()
                for (index, file) in prepared.files.enumerated() {
                    try Task.checkCancellation()
                    self.status = prepared.files.count == 1 ? "正在转写，请稍候…" : "正在转写第 \(index + 1) / \(prepared.files.count) 段…"
                    let text = try await self.client.transcribe(fileURL: file, apiKey: key, options: options)
                    try Task.checkCancellation()
                    partial += (partial.isEmpty ? "" : "\n\n") + text
                    self.draftText = partial
                    self.progress = Double(index + 1) / Double(prepared.files.count)
                    // Checkpoint every completed chunk, including while a later
                    // request is in flight or the user chooses to quit.
                    guard self.saveEdits() else { throw UserFacingError("部分文字尚未保存，请先导出文本后再继续。") }
                    self.notice = nil
                }
                let record = TranscriptRecord(id: recordID, title: title, text: partial, createdAt: self.draftCreatedAt, sourceName: name)
                try self.history.save(record)
                self.selectedRecordID = recordID
                self.draftTitle = title
                self.status = "转写完成"
                self.notice = "文字已保存在本机，可直接编辑"
                self.clearSource()
            } catch {
                let cancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
                self.status = cancelled ? "已取消转写" : "转写未完成"
                if !partial.isEmpty {
                    if !self.saveEdits() { self.errorMessage = "已生成部分文字，但本地保存失败。请先导出文本。" }
                }
                if !cancelled { self.errorMessage = self.errorMessage ?? error.localizedDescription }
                self.notice = "可以再次转写；重试会重新处理完整音频。"
            }
        }
    }

    func cancelTranscription() {
        if isImportingAudio {
            cancelAudioImport()
            return
        }
        operation?.cancel()
        status = "正在取消…"
    }

    func cancelAudioImport() {
        guard isImportingAudio else { return }
        invalidatePendingImport()
        status = sourceURL == nil ? "已取消导入" : "音频已就绪"
    }

    func newTranscript() {
        guard !isWorking, saveEdits() else { return }
        resetDraft()
    }

    func selectRecord(_ record: TranscriptRecord) {
        guard selectedRecordID != record.id else { return }
        guard !isWorking, saveEdits() else { return }
        clearSource()
        let current = history.records.first(where: { $0.id == record.id }) ?? record
        selectedRecordID = current.id
        draftTitle = current.title
        draftText = current.text
        sourceName = current.sourceName
        draftCreatedAt = current.createdAt
        status = "本地记录"
        errorMessage = nil
        notice = nil
    }

    func deleteRecord(_ record: TranscriptRecord) {
        guard !isWorking else { return }
        do {
            try history.delete(id: record.id)
            if selectedRecordID == record.id { resetDraft() }
        } catch { errorMessage = error.localizedDescription }
    }

    @discardableResult
    func saveEdits() -> Bool {
        guard hasEdits else { return true }
        let id = selectedRecordID ?? UUID()
        let old = history.records.first(where: { $0.id == id })
        do {
            try history.save(TranscriptRecord(id: id, title: draftTitle.isEmpty ? t("未命名转写") : draftTitle,
                                             text: draftText, createdAt: old?.createdAt ?? draftCreatedAt,
                                             sourceName: old?.sourceName ?? sourceName, model: old?.model ?? TranscriptionOptions.model))
            selectedRecordID = id
            notice = "修改已保存"
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draftText, forType: .string)
        notice = "已复制文字"
    }

    func exportText() {
        guard !draftText.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = t("导出转写文字")
        panel.prompt = t("导出")
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = draftTitle.replacingOccurrences(of: "/", with: "-") + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try draftText.write(to: url, atomically: true, encoding: .utf8)
            notice = "文本已导出"
        } catch { errorMessage = "无法导出文本：\(error.localizedDescription)" }
    }

    func shutdown() async -> Bool {
        isTerminating = true
        defer { isTerminating = false }
        invalidatePendingImport()
        operation?.cancel()
        await operation?.value
        guard saveEdits() else { return false }
        recorder.discard()
        clearSource()
        return true
    }

    private func invalidatePendingImport() {
        pendingImportID = nil
        isImportingAudio = false
    }

    private func resetDraft() {
        clearSource()
        selectedRecordID = nil
        draftCreatedAt = Date()
        draftText = ""
        draftTitle = t("新的转写")
        status = "准备就绪"
        progress = 0
        errorMessage = nil
        notice = nil
    }

    private func clearSource() {
        if let ownedRecording { try? FileManager.default.removeItem(at: ownedRecording) }
        ownedRecording = nil
        sourceURL = nil
        sourceName = ""
    }
}

struct UserFacingError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
