import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var recoveredRecordingURL: URL?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var ownedRecoveredURL: URL?
    private var timer: Timer?
    private var isStarting = false
    private var generation = 0

    func start() async throws {
        guard !isStarting, !isRecording else { throw RecordingError.alreadyRecording }
        guard recoveredRecordingURL == nil else { throw RecordingError.recoveryPending }
        isStarting = true
        generation += 1
        let startingGeneration = generation
        defer { isStarting = false }
        errorMessage = nil
        elapsed = 0
        level = 0

        do {
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                authorized = true
            case .notDetermined:
                authorized = await AVCaptureDevice.requestAccess(for: .audio)
            default:
                authorized = false
            }
            try Task.checkCancellation()
            guard generation == startingGeneration else { throw CancellationError() }
            guard authorized else { throw RecordingError.permissionDenied }

            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LocalTranscriberRecordings", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
            recordingURL = url
            let audioRecorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            audioRecorder.delegate = self
            audioRecorder.isMeteringEnabled = true
            recorder = audioRecorder
            guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
                throw RecordingError.couldNotStart
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.updateMeters() }
            }
        } catch {
            discard()
            if !(error is CancellationError) {
                errorMessage = (error as? RecordingError)?.localizedDescription
                    ?? "无法开始录音：\(error.localizedDescription)"
            }
            throw error
        }
    }

    /// Ownership of the returned recording is transferred to the caller.
    func stop() -> URL? {
        generation += 1
        timer?.invalidate()
        timer = nil
        if let recorder {
            elapsed = recorder.currentTime
            recorder.delegate = nil
            recorder.stop()
        }
        recorder = nil
        isRecording = false
        level = 0
        let result = recordingURL
        recordingURL = nil
        return result
    }

    func discard() {
        if let url = stop() { try? FileManager.default.removeItem(at: url) }
        if let url = takeRecoveredRecording() { try? FileManager.default.removeItem(at: url) }
    }

    /// Ownership of an interrupted recording is transferred to the caller.
    func takeRecoveredRecording() -> URL? {
        let result = ownedRecoveredURL
        ownedRecoveredURL = nil
        recoveredRecordingURL = nil
        return result
    }

    private func updateMeters() {
        guard let recorder, isRecording else { return }
        guard recorder.isRecording else {
            handleUnexpectedFinish(recorder, message: "录音意外结束，请检查麦克风连接。")
            return
        }
        elapsed = recorder.currentTime
        recorder.updateMeters()
        level = min(1, max(0, pow(10, recorder.averagePower(forChannel: 0) / 20)))
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handleUnexpectedFinish(
                recorder,
                message: flag ? "录音意外结束。" : "录音保存未正常完成，请检查可用磁盘空间。"
            )
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let detail = error?.localizedDescription ?? "音频编码失败"
        Task { @MainActor [weak self] in
            self?.handleUnexpectedFinish(recorder, message: "录音失败：\(detail)")
        }
    }

    private func handleUnexpectedFinish(_ source: AVAudioRecorder, message: String) {
        guard source === recorder else { return }
        guard let url = stop() else {
            errorMessage = message
            return
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if attributes?[.type] as? FileAttributeType == .typeRegular,
           let size = attributes?[.size] as? NSNumber, size.int64Value > 0 {
            errorMessage = "\(message) 已保留录音文件，可尝试转写。"
            ownedRecoveredURL = url
            recoveredRecordingURL = url
        } else {
            try? FileManager.default.removeItem(at: url)
            errorMessage = "\(message) 未能恢复录音，请重新录制。"
        }
    }

    deinit {
        timer?.invalidate()
        recorder?.delegate = nil
        recorder?.stop()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        if let ownedRecoveredURL { try? FileManager.default.removeItem(at: ownedRecoveredURL) }
    }
}

private enum RecordingError: LocalizedError {
    case alreadyRecording
    case permissionDenied
    case couldNotStart
    case recoveryPending

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "录音正在进行中。"
        case .permissionDenied:
            return "麦克风权限未开启。请在“系统设置 → 隐私与安全性 → 麦克风”中允许本应用访问。"
        case .couldNotStart:
            return "无法开始录音，请检查麦克风连接和可用磁盘空间。"
        case .recoveryPending:
            return "上次中断的录音尚未处理，请先保存或转写该录音。"
        }
    }
}
