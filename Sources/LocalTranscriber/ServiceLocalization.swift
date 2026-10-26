import Foundation

extension AppLocalization {
    /// Service errors stay in their canonical language until presentation. This
    /// lets an existing warning follow an interface-language change without
    /// touching transcript content, filenames, or the services' error handling.
    static let serviceStrings: [String: String] = [
        // Recording
        "录音意外结束，请检查麦克风连接。": "Recording ended unexpectedly. Check your microphone connection.",
        "录音意外结束。": "Recording ended unexpectedly.",
        "录音保存未正常完成，请检查可用磁盘空间。": "The recording could not be saved completely. Check available disk space.",
        "音频编码失败": "Audio encoding failed.",
        "录音失败：": "Recording failed.",
        "无法开始录音：": "Could not start recording.",
        "录音正在进行中。": "A recording is already in progress.",
        "麦克风权限未开启。请在“系统设置 → 隐私与安全性 → 麦克风”中允许本应用访问。": "Microphone access is disabled. Allow this app in System Settings → Privacy & Security → Microphone.",
        "无法开始录音，请检查麦克风连接和可用磁盘空间。": "Could not start recording. Check your microphone connection and available disk space.",
        "上次中断的录音尚未处理，请先保存或转写该录音。": "An interrupted recording is waiting. Save or transcribe it before starting another recording.",

        // Import validation
        "请一次导入一个音频或视频文件。": "Import one audio or video file at a time.",
        "仅支持导入本机文件，请先将音频下载到 Mac。": "Only local files can be imported. Download the audio to your Mac first.",
        "无法读取所选文件，请确认文件仍然存在且有读取权限。": "Could not read the selected file. Check that it still exists and you have permission to read it.",
        "请导入音频或视频文件，不能导入文件夹或快捷方式。": "Choose an audio or video file. Folders and shortcuts cannot be imported.",
        "无法读取所选文件，请确认你有读取权限。": "Could not read the selected file. Check that you have permission to read it.",
        "所选文件为空，请选择包含录音内容的音频或视频文件。": "The selected file is empty. Choose an audio or video file containing a recording.",
        "不支持此文件类型，请选择 MP3、M4A、WAV、FLAC 等音频，或包含声音的视频文件。": "This file type is not supported. Choose audio such as MP3, M4A, WAV, or FLAC, or a video with an audio track.",

        // Conversion and segmentation
        "正在读取音频…": "Reading audio…",
        "音频准备完成。": "Audio preparation complete.",
        "音频转换失败。": "Audio conversion failed.",
        "无法读取所选音频，请确认文件仍然存在且有读取权限。": "Could not read the selected audio. Check that it still exists and you have permission to read it.",
        "所选文件为空或不是普通音频文件。": "The selected file is empty or is not a regular audio file.",
        "所选文件中没有可用的音轨。": "The selected file has no usable audio track.",
        "macOS 无法转换此音频。请先将文件转换为 M4A、MP3 或 WAV，再重新导入。": "macOS cannot convert this audio. Convert it to M4A, MP3, or WAV, then import it again.",
        "无法读取音频时长，请尝试重新导出音频文件。": "Could not read the audio duration. Try exporting the audio file again.",
        "请检查文件格式和可用磁盘空间。": "Check the file format and available disk space.",
        "音频分段后仍超过上传限制，请先转换为单声道 M4A 再导入。": "An audio segment still exceeds the upload limit. Convert the audio to mono M4A before importing it.",
        "无法创建或读取临时音频文件，请检查可用磁盘空间后重试。": "Could not create or read temporary audio files. Check available disk space and try again.",

        // History and Keychain
        "无法访问本地历史记录。为保护已有记录，已暂停保存；请检查应用支持目录的访问权限后重新打开应用。": "Could not access local history. Saving is paused to protect existing records. Check permissions for the Application Support folder, then reopen the app.",
        "历史记录文件损坏，且无法安全保留原文件。已暂停保存，原文件未被覆盖；请备份并检查历史记录目录后重新打开应用。": "The history file is damaged and could not be safely backed up. Saving is paused and the original file has not been overwritten. Back up and check the history folder, then reopen the app.",
        "本地历史记录当前不可写。已有文件会保留，请检查历史记录目录后重新打开应用。": "Local history is currently read-only. Existing files are preserved. Check the history folder, then reopen the app.",
        "无法保存本地历史记录。请检查磁盘空间和目录权限；已有记录未被覆盖。": "Could not save local history. Check disk space and folder permissions. Existing records have not been overwritten.",
        "请输入 OpenAI API Key。": "Enter your OpenAI API key.",
        "钥匙串中的 API Key 无法读取，请重新保存。": "The API key in Keychain could not be read. Save it again.",

        // TranscriptionClient validation, transport, and API errors
        "请填写有效的 OpenAI API Key，密钥中不能含有空格或换行。": "Enter a valid OpenAI API key without spaces or line breaks.",
        "无法读取音频文件，请确认文件仍然存在且可以访问。": "Could not read the audio file. Check that it still exists and is accessible.",
        "音频文件为空，请重新录音或选择其他文件。": "The audio file is empty. Record again or choose another file.",
        "音频超过本软件的 24 MB 限制，请缩短录音或选择较小的文件。": "The audio exceeds this app's 24 MB limit. Use a shorter recording or a smaller file.",
        "不支持此音频格式。请选择 M4A、MP3、WAV、FLAC、MP4、MPEG、MPGA、OGG 或 WebM。": "This audio format is not supported. Choose M4A, MP3, WAV, FLAC, MP4, MPEG, MPGA, OGG, or WebM.",
        "语言提示最多填写 5 个语言代码，例如 zh、en、yue 或 zh-cn。": "Provide up to 5 language codes, such as zh, en, yue, or zh-cn.",
        "关键词最多 100 个，每个最多 100 个字符，且不能含换行、<、> 或空字符。": "Provide up to 100 keywords, each at most 100 characters, without line breaks, <, >, or null characters.",
        "转写说明最多 4,000 个字符，且不能含空字符。": "Transcription instructions must be at most 4,000 characters and cannot contain null characters.",
        "API Key 无效或已过期，请在设置中更新密钥。": "The API key is invalid or expired. Update it in Settings.",
        "此 API Key 或项目没有转写权限，请检查 OpenAI 项目权限和地区可用性。": "This API key or project does not have transcription access. Check the OpenAI project permissions and regional availability.",
        "当前项目无法使用 gpt-transcribe，请检查该模型的访问权限。": "This project cannot use gpt-transcribe. Check its model access.",
        "请求过于频繁，请稍后重试或检查 OpenAI 项目的速率限制。": "Too many requests. Try again later or check the OpenAI project's rate limits.",
        "OpenAI API 额度不足，请检查 API 账户余额和项目预算。ChatGPT 订阅不包含 API 额度。": "Insufficient OpenAI API credit. Check your API balance and project budget. ChatGPT subscriptions do not include API credit.",
        "OpenAI 拒绝了过大的音频，请缩短录音或选择较小的文件。": "OpenAI rejected the audio because it is too large. Use a shorter recording or a smaller file.",
        "OpenAI 服务暂时不可用，请稍后重试。": "OpenAI is temporarily unavailable. Try again later.",
        "OpenAI 返回了无法识别的结果，请稍后重试。": "OpenAI returned an unrecognized result. Try again later.",
        "没有识别到文字，请确认音频中有清晰的人声。": "No speech was transcribed. Check that the audio contains clear speech.",
        "无法连接 OpenAI，请检查网络连接或代理设置。": "Could not connect to OpenAI. Check your network connection or proxy settings.",
        "转写请求超时，请检查网络或使用较短的音频重试。": "The transcription request timed out. Check your connection or retry with shorter audio.",
        "转写连接中断，请检查网络后重试。": "The transcription connection was interrupted. Check your network and try again.",
        "服务器要求重定向；为保护 API Key，已停止请求。": "The server requested a redirect. The request was stopped to protect your API key.",
    ]

    static let servicePatterns: [LocalizedMessagePattern] = [
        // Match outer wrappers before inner errors, so nested application-owned
        // details can be translated without altering arbitrary OS error text.
        .init(#"^([\s\S]+) 已保留录音文件，可尝试转写。$"#,
              "%@ The recording has been retained; you can try transcribing it.", translatedArguments: [0]),
        .init(#"^([\s\S]+) 未能恢复录音，请重新录制。$"#,
              "%@ The recording could not be recovered. Record it again.", translatedArguments: [0]),
        .init(#"^无法开始录音：([\s\S]+)$"#,
              "Could not start recording: %@", translatedArguments: [0]),
        .init(#"^录音失败：([\s\S]+)$"#,
              "Recording failed: %@", translatedArguments: [0]),
        .init(#"^正在准备第 ([0-9]+) 段音频…$"#,
              "Preparing audio segment %@…"),
        .init(#"^音频已分为 ([0-9]+) 段，将依次转写。$"#,
              "Audio split into %@ segments for sequential transcription."),
        .init(#"^音频转换失败。([\s\S]+)$"#,
              "Audio conversion failed. %@", translatedArguments: [0]),
        .init(#"^历史记录文件无法读取，原文件已保留为 ([\s\S]+)。可以继续保存新记录。$"#,
              "The history file could not be read. The original was preserved as %@. You can continue saving new records."),
        .init(#"^无法读取钥匙串中的 API Key（系统错误 (-?[0-9]+)）。请确认登录钥匙串已解锁。$"#,
              "Could not read the API key from Keychain (system error %@). Make sure your login keychain is unlocked."),
        .init(#"^无法保存钥匙串中的 API Key（系统错误 (-?[0-9]+)）。请确认登录钥匙串已解锁。$"#,
              "Could not save the API key to Keychain (system error %@). Make sure your login keychain is unlocked."),
        .init(#"^无法移除钥匙串中的 API Key（系统错误 (-?[0-9]+)）。请确认登录钥匙串已解锁。$"#,
              "Could not remove the API key from Keychain (system error %@). Make sure your login keychain is unlocked."),
        .init(#"^转写请求未被接受（HTTP ([0-9]+)），请检查音频是否有效以及转写提示是否合适。$"#,
              "The transcription request was rejected (HTTP %@). Check the audio file and transcription hints."),
    ]
}
