import AVFoundation
import Foundation

struct PreparedAudio: Sendable {
    let files: [URL]
    let temporaryDirectory: URL?

    func cleanup() {
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
    }
}

enum AudioPreparation {
    // Leave headroom below the API's 25 MB upload limit.
    static let maximumUploadBytes: Int64 = 24_000_000
    static let supportedExtensions: Set<String> = [
        "mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm", "flac", "ogg"
    ]

    static func prepare(
        url: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> PreparedAudio {
        try Task.checkCancellation()
        let size = try fileSize(url)
        if supportedExtensions.contains(url.pathExtension.lowercased()), size <= maximumUploadBytes {
            return PreparedAudio(files: [url], temporaryDirectory: nil)
        }

        progress("正在读取音频…")
        let asset = AVURLAsset(url: url)
        let duration: CMTime
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard !tracks.isEmpty else { throw PreparationError.noAudio }
            duration = try await asset.load(.duration)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as PreparationError {
            throw error
        } catch {
            throw PreparationError.cannotDecode
        }
        try Task.checkCancellation()
        guard duration.isNumeric, duration.seconds.isFinite, duration.seconds > 0 else {
            throw PreparationError.invalidDuration
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalTranscriber-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw PreparationError.temporaryStorage
        }
        do {
            var files: [URL] = []
            let chunkDuration = CMTime(seconds: 600, preferredTimescale: 600)
            var cursor = CMTime.zero
            while CMTimeCompare(cursor, duration) < 0 {
                try Task.checkCancellation()
                let remaining = CMTimeSubtract(duration, cursor)
                let length = CMTimeCompare(remaining, chunkDuration) < 0 ? remaining : chunkDuration
                progress("正在准备第 \(files.count + 1) 段音频…")
                let chunks = try await exportRange(
                    asset: asset,
                    range: CMTimeRange(start: cursor, duration: length),
                    directory: directory
                )
                files.append(contentsOf: chunks)
                cursor = CMTimeAdd(cursor, length)
            }
            try Task.checkCancellation()
            guard !files.isEmpty else { throw PreparationError.noAudio }
            progress(files.count > 1 ? "音频已分为 \(files.count) 段，将依次转写。" : "音频准备完成。")
            return PreparedAudio(files: files, temporaryDirectory: directory)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            if !(error is CancellationError), !(error is PreparationError) {
                throw PreparationError.temporaryStorage
            }
            throw error
        }
    }

    private static func exportRange(asset: AVURLAsset, range: CMTimeRange, directory: URL) async throws -> [URL] {
        try Task.checkCancellation()
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A),
              session.supportedFileTypes.contains(.m4a) else {
            throw PreparationError.cannotDecode
        }
        let output = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        session.outputURL = output
        session.outputFileType = .m4a
        session.timeRange = range
        let operation = CancellableAudioExport(session: session)
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                operation.start { continuation.resume() }
            }
            try Task.checkCancellation()
            guard session.status == .completed else {
                if session.status == .cancelled { throw CancellationError() }
                throw PreparationError.exportFailed(session.error?.localizedDescription)
            }
        } onCancel: {
            operation.cancel()
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        let size = try fileSize(output)
        if size < maximumUploadBytes { return [output] }

        // A source with unusually high channel count or bitrate can still produce
        // a large AAC file. Halve that range and verify each resulting file.
        try FileManager.default.removeItem(at: output)
        guard range.duration.seconds > 1 else { throw PreparationError.chunkTooLarge }
        let firstDuration = CMTimeMultiplyByFloat64(range.duration, multiplier: 0.5)
        let secondDuration = CMTimeSubtract(range.duration, firstDuration)
        let first = try await exportRange(
            asset: asset,
            range: CMTimeRange(start: range.start, duration: firstDuration),
            directory: directory
        )
        let second = try await exportRange(
            asset: asset,
            range: CMTimeRange(start: CMTimeAdd(range.start, firstDuration), duration: secondDuration),
            directory: directory
        )
        return first + second
    }

    private static func fileSize(_ url: URL) throws -> Int64 {
        guard url.isFileURL, FileManager.default.isReadableFile(atPath: url.path) else {
            throw PreparationError.unreadableFile
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw PreparationError.unreadableFile
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
            throw PreparationError.emptyFile
        }
        return size.int64Value
    }
}

// Serialize cancellation against starting the legacy macOS 14 export API, so a
// cancellation just before export begins cannot leave an export running behind.
private final class CancellableAudioExport: @unchecked Sendable {
    private let session: AVAssetExportSession
    private let lock = NSLock()
    private var cancelled = false

    init(session: AVAssetExportSession) { self.session = session }

    func start(completion: @escaping @Sendable () -> Void) {
        lock.lock()
        if cancelled {
            lock.unlock()
            completion()
            return
        }
        session.exportAsynchronously(completionHandler: completion)
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        session.cancelExport()
        lock.unlock()
    }
}

private enum PreparationError: LocalizedError {
    case unreadableFile
    case emptyFile
    case noAudio
    case cannotDecode
    case invalidDuration
    case exportFailed(String?)
    case chunkTooLarge
    case temporaryStorage

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "无法读取所选音频，请确认文件仍然存在且有读取权限。"
        case .emptyFile:
            return "所选文件为空或不是普通音频文件。"
        case .noAudio:
            return "所选文件中没有可用的音轨。"
        case .cannotDecode:
            return "macOS 无法转换此音频。请先将文件转换为 M4A、MP3 或 WAV，再重新导入。"
        case .invalidDuration:
            return "无法读取音频时长，请尝试重新导出音频文件。"
        case .exportFailed(let detail):
            return "音频转换失败。\(detail.map { "\($0)" } ?? "请检查文件格式和可用磁盘空间。")"
        case .chunkTooLarge:
            return "音频分段后仍超过上传限制，请先转换为单声道 M4A 再导入。"
        case .temporaryStorage:
            return "无法创建或读取临时音频文件，请检查可用磁盘空间后重试。"
        }
    }
}
