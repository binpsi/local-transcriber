import Foundation
import UniformTypeIdentifiers

enum AudioImport {
    // Keep common native formats usable even if Launch Services cannot resolve
    // their UTType (for example in a test host or a freshly registered app).
    private static let nativeExtensions: Set<String> = [
        "aif", "aiff", "aifc", "caf", "mov", "aac", "m4b", "m4v"
    ]

    static var allowedContentTypes: [UTType] {
        [UTType.audio, .movie] + AudioPreparation.supportedExtensions.union(nativeExtensions).sorted()
            .compactMap { UTType(filenameExtension: $0) }
    }

    static func validate(_ urls: [URL]) throws -> URL {
        guard urls.count == 1, let originalURL = urls.first else {
            throw UserFacingError("请一次导入一个音频或视频文件。")
        }
        guard originalURL.isFileURL,
              originalURL.host == nil || originalURL.host == "" || originalURL.host?.lowercased() == "localhost" else {
            throw UserFacingError("仅支持导入本机文件，请先将音频下载到 Mac。")
        }
        let url = originalURL.standardizedFileURL
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw UserFacingError("无法读取所选文件，请确认文件仍然存在且有读取权限。")
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw UserFacingError("请导入音频或视频文件，不能导入文件夹或快捷方式。")
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw UserFacingError("无法读取所选文件，请确认你有读取权限。")
        }
        guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
            throw UserFacingError("所选文件为空，请选择包含录音内容的音频或视频文件。")
        }
        let fileExtension = url.pathExtension.lowercased()
        let extensionType = UTType(filenameExtension: fileExtension)
        let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        let isMedia = [extensionType, fileType].compactMap { $0 }.contains {
            $0.conforms(to: .audio) || $0.conforms(to: .movie)
        }
        guard AudioPreparation.supportedExtensions.contains(fileExtension) || nativeExtensions.contains(fileExtension) || isMedia else {
            throw UserFacingError("不支持此文件类型，请选择 MP3、M4A、WAV、FLAC 等音频，或包含声音的视频文件。")
        }
        return url
    }

    static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        if let string = item as? String { return URL(string: string) }
        return nil
    }
}
