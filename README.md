# 听写 · Local Transcriber

[简体中文](#简体中文) | [English](#english)

## 简体中文

**用自己的 OpenAI API Key，把录音和音频文件转成文字。**

听写是一款轻量的原生 macOS 应用，使用 SwiftUI 构建，固定调用 OpenAI `gpt-transcribe` 模型。适合整理口述、访谈、会议录音和学习笔记：录音或导入文件，转写后直接校对、复制、导出。

当前版本：**v1.2.0**，支持在应用内即时切换简体中文和 English。

> **本地客户端，云端转写。** 应用在 Mac 上运行；发起转写时，音频会直接上传至 OpenAI。需要网络及可用的 OpenAI API 额度，API 费用由你的账户承担。

### 功能

- **中英文界面**：侧栏和设置均提供“界面语言 / Interface language”，切换后立即生效并保存选择。
- **原生轻量**：SwiftUI + macOS 系统框架，无第三方依赖，无需 Electron 或 Python 运行时；本机构建的 App 约 2 MB，实际大小随架构和工具链变化。
- **麦克风录音**：点击开始，停止后转写；首次使用由系统请求麦克风权限。
- **拖拽或点击导入**：把文件拖入虚线区域，拖入时高亮；也可点击区域或“选择文件”。每次导入一个文件，导入本身不会上传音频。
- **长音频处理**：超出本地上传阈值时自动转换、分段并依次转写，展示处理进度，可取消。
- **语言与术语提示**：自动识别语言，也可指定普通话、英语、中英混合、粤语或日语，补充专有名词与录音背景。
- **编辑与导出**：在应用内修改转写文字，一键复制或导出 UTF-8 TXT。
- **本地历史**：保留最近 100 条记录，支持搜索、重命名和删除，逐段保存已完成的文字。
- **钥匙串保存密钥**：API Key 存放在 macOS 钥匙串，可在设置中移除。

### 快速开始

#### 1. 下载 DMG 并安装

当前 DMG 安装包支持 **Apple Silicon（M 系列芯片）Mac、macOS 14 或更新版本**，不支持 Intel Mac。安装后即可使用，无需安装 Xcode 或自行编译。

1. 打开本仓库的 **Releases** 页面，在 **v1.2.0** 的 **Assets** 中下载 **`LocalTranscriber-v1.2.0-macOS-arm64.dmg`**。
2. 双击 DMG，打开“听写”磁盘映像。
3. 将窗口中的 **“听写.app”拖到旁边的 Applications（应用程序）快捷方式**，等待复制完成。
4. 在 Finder 中推出“听写”磁盘映像，然后从 Mac 的“应用程序”文件夹打开“听写”。
5. 按下面的步骤配置自己的 OpenAI API Key。

**从旧版升级**：先退出正在运行的听写，再将新版 `听写.app` 拖入 Applications，并在系统询问时选择“替换”。复制完成后推出磁盘映像，从“应用程序”启动新版。替换 App 会保留本机转写历史、应用设置和钥匙串中的 API Key。

**首次打开提示**：当前版本采用本地临时签名（ad hoc），尚未完成 Apple Developer ID 签名和公证。如果 macOS 提示无法验证开发者，在确认安装包来源可信且未被篡改后，可按 [Apple 官方指引](https://support.apple.com/zh-cn/102445)，到“系统设置 → 隐私与安全性”中选择“仍要打开”，再按提示确认。

#### 2. 配置 API Key

打开“设置与 API Key”，粘贴在 [OpenAI 平台](https://platform.openai.com/api-keys) 创建的 API Key，然后保存。密钥所属项目需要有可用额度和 `gpt-transcribe` 模型访问权限。

无需创建 `.env`，也无需把密钥写入源码。

#### 3. 开始转写

1. **录音**：点击“开始录音”，讲话结束后点击“停止并转写”。
2. **文件**：拖入音频、点击导入区域或使用“导入音频”菜单，确认文件后点击“转写音频”。
3. **校对**：编辑结果后按 `⌘S` 保存；切换记录或正常退出时也会保存修改。
4. **导出**：复制文字，或按 `⌘⇧E` 导出 TXT。

应用只在你点击录音按钮后使用麦克风，不采集系统声音。

#### 4. 切换界面语言

在侧栏底部或设置中的 **“界面语言 / Interface language”** 选择 **“简体中文”** 或 **“English”**，无需重启即可生效，后续启动会恢复已保存的选择。首次启动时，系统首选语言为中文则使用简体中文，其余语言使用 English。

界面语言与 **“音频语言 / Audio language”** 独立：前者控制应用自有界面、提示和菜单的显示，后者用于提示录音中的语言。切换界面语言不会翻译或修改历史正文、文件名、用户填写的标题和其他输入内容。macOS 原生菜单及系统授权提示仍遵循系统语言设置。

### 模型、格式与准确度

应用固定使用 **`gpt-transcribe`**，不会自动切换到其他模型。根据 2026-10-23 核对的 [OpenAI 文件转写指南](https://developers.openai.com/api/docs/guides/speech-to-text) 和 [模型说明](https://developers.openai.com/api/docs/models/gpt-transcribe)，它是官方推荐的高准确度文件转写模型。实际效果仍受噪音、口音、重叠说话和专业术语影响，重要内容应人工校对。

- 保留原始语言，不自动翻译，也不额外调用文本模型改写结果。
- “提升识别准确度”中的关键词和录音背景会随转写请求发送，适合填写人名、品牌名、缩写等录音相关信息。
- 不超过 **24 MB** 的 MP3、M4A、WAV、MP4、MPEG、MPGA、FLAC、OGG 和 WebM 可直接上传。
- 较大文件及其他可导入的媒体格式，由 macOS 原生组件转换为 M4A，并按最长 **10 分钟** 分段；必要时继续细分，以满足大小限制。
- 转换需要 macOS 能解码源文件。若无法读取，请先转为 M4A、MP3 或 WAV；视频文件需要包含可用音轨。
- 分段切点可能落在句中，建议复核段落衔接处。当前版本不提供说话人区分、字幕时间轴或实时逐字转写。

### 隐私与数据保存

**上传内容**：仅在发起转写时，将所选音频或录音及填写的语言、关键词、背景提示直接发送至 OpenAI。应用没有自建中转服务，也不包含遥测。

**API Key**：保存在 macOS 钥匙串，service 为 `com.localtranscriber.mac`。不写入源码、UserDefaults、日志或转写历史，不启用钥匙串同步。

**转写历史**：保存在 `~/Library/Application Support/LocalTranscriber/history.json`，最多保留最近 100 条。目录权限为 `0700`，文件权限为 `0600`；历史是本机明文文件。界面语言、音频语言、关键词和背景提示保存在本机应用设置中。

**音频文件**：导入的原始文件不修改、不删除。临时录音在成功转写、放弃、切换任务或正常退出时删除；失败或取消后保留，以便重试。转换及上传使用的临时副本会在处理结束后清理，强制退出或崩溃可能留下系统临时文件。

**中断与重试**：每完成一段都会保存部分文字。重试会重新处理完整音频、创建新记录，并产生相应 API 费用；之前保存的部分结果不会被覆盖。麦克风意外中断时，应用会尽可能保留可用录音。

### 快捷键

- `⌘N`：新建转写
- `⌘O`：导入音频
- `⌘⇧R`：开始录音 / 停止并转写
- `⌘S`：保存编辑
- `⌘⇧E`：导出文本
- `⌘,`：设置

### 开发与验证

使用 Swift Package Manager 管理项目，界面基于 SwiftUI，音频处理使用 AVFoundation，密钥存储使用 Security 框架。

#### 从源码构建

需要 **macOS 14 或更新版本**，以及包含 **Swift 6** 的 Xcode 或 Command Line Tools。可先用 `swift --version` 确认工具链版本。

```sh
git clone <仓库地址> local-transcriber
cd local-transcriber
bash scripts/build-app.sh
open "dist/听写.app"
```

将 `<仓库地址>` 替换为本仓库的 GitHub 克隆地址。构建脚本会生成：

- `dist/听写.app`：可在本机运行的应用。
- `dist/LocalTranscriber-macOS.zip`：App 的 ZIP 归档。
- `dist/LocalTranscriber-v1.2.0-macOS-arm64.dmg`：带版本号的 DMG 安装包。
- `dist/LocalTranscriber-macOS-arm64.dmg`：同一安装包的固定文件名副本，便于保留现有下载链接。

上述 DMG 文件名对应 Apple Silicon 构建。脚本默认构建当前 Mac 的架构，不生成 Universal Binary；DMG 文件名中的版本号与架构从 App 自动读取。脚本会使用本地临时签名（ad hoc）签署 App，并自动生成 ZIP 和 DMG。

如果只需重新封装已有的 `dist/听写.app`，运行：

```sh
bash scripts/build-dmg.sh
```

此命令验证并保留已有 App 签名，不重新编译或重新签名。

#### 项目结构与测试

```text
.
├── Package.swift
├── Sources/
│   ├── LocalTranscriber/       # 界面、录音、导入、预处理与本地存储
│   └── TranscriberCore/        # OpenAI 请求、参数校验、错误及取消处理
├── Tests/
│   ├── LocalTranscriberTests/  # 文件导入、状态、历史与界面本地化测试
│   └── TranscriberCoreTests/   # 模拟 API 请求测试
├── Resources/                 # App 元信息与签名权限
└── scripts/                   # App 打包与图标生成
```

在仓库根目录运行测试，不需要 API Key，也不会发起真实 API 请求：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift test --disable-sandbox
```

当前版本 **1.2.0** 的 40 项自动测试已通过：7 项文件导入测试、9 项本地状态与历史测试、11 项模拟转写 API 测试，以及 13 项界面本地化测试。自动测试不会调用真实 OpenAI API；真实麦克风录音与真实 API 转写仍需在配置密钥和授权后验证。

#### 发布到 GitHub Releases

在 GitHub 网页创建 Release，建议使用标签 **`v1.2.0`**。将 `dist/LocalTranscriber-v1.2.0-macOS-arm64.dmg` 上传到附件区域，并将 [RELEASE_NOTES.md](RELEASE_NOTES.md) 的中英文内容复制到发布说明中。如果需要继续使用指向固定附件名的下载链接，同时上传 `dist/LocalTranscriber-macOS-arm64.dmg`。确认附件上传完成后，再发布 Release。DMG 包含“听写.app”和 Applications 快捷方式，用户可以直接拖拽安装。

如果后续完成 Developer ID 签名和 Apple 公证，应使用 `bash scripts/build-dmg.sh` 重新封装最终 App，再上传 DMG，同时更新 README 和发布说明中的签名状态。签名与公证需在构建之后完成；不要在完成后再次运行会覆盖签名的 `build-app.sh`。

### 常见问题

**构建提示缺少 Swift 或工具链版本过低**

安装包含 Swift 6 的 Xcode 或 Command Line Tools，确认 `swift --version`，再运行构建脚本。

**API Key 无效、余额不足或模型不可用**

检查密钥所属的 OpenAI 项目、API 额度和模型访问权限。应用会显示错误，不会自动改用其他模型。

**无法录音或没有麦克风权限**

在“系统设置 → 隐私与安全性 → 麦克风”中允许听写访问。请从构建出的 `.app` 启动，使系统正确识别权限说明，并确认当前输入设备可用。

**文件无法导入或转换**

每次导入一个已下载到本机的非空音频或视频文件；不能直接拖入文件夹、快捷方式或网页地址。格式无法解码时，先转换为 M4A、MP3 或 WAV。

**网络错误或转写被中断**

检查网络和 macOS 代理设置，再重试保留的音频。已完成的分段文字会保留；重试会重新转写完整音频。

**历史记录保存失败**

先复制或导出当前文字，检查磁盘空间和历史目录权限。应用会阻止会丢弃未保存文字的切换操作；目录不可访问时，修复后重新启动应用。

---

## English

**Turn recordings and audio files into text with your own OpenAI API key.**

Local Transcriber (听写) is a lightweight native macOS app built with SwiftUI. It uses OpenAI's `gpt-transcribe` model to transcribe dictation, interviews, meetings, and study notes. Record or import audio, then review, copy, or export the transcript.

Current version: **v1.2.0**, with instant switching between Simplified Chinese and English in the app.

> **Local app, cloud transcription.** The app runs on your Mac. When you start transcription, audio is uploaded directly to OpenAI. An internet connection and available OpenAI API credit are required; API charges are billed to your account.

### Features

- **Chinese and English interface:** Use “界面语言 / Interface language” in the sidebar or settings. Changes take effect immediately and are saved.
- **Lightweight native app:** SwiftUI and macOS system frameworks, with no third-party dependencies, Electron, or Python runtime. The locally built app is approximately 2 MB; size varies by architecture and toolchain.
- **Microphone recording:** Start recording and transcribe when you stop. macOS requests microphone permission on first use.
- **Drag-and-drop or file selection:** Drop a file into the highlighted import area, click the area, or choose a file. Import one file at a time; importing alone does not upload audio.
- **Long audio:** Files above the local upload threshold are converted, split, and transcribed sequentially, with progress updates and cancellation.
- **Language and terminology hints:** Detect the language automatically or choose Mandarin Chinese, English, mixed Chinese and English, Cantonese, or Japanese. Add names, terminology, and recording context.
- **Editing and export:** Edit text in the app, copy it, or export it as UTF-8 TXT.
- **Local history:** Keep the latest 100 records, with search, rename, and delete. Completed transcript segments are saved as processing progresses.
- **Keychain storage:** Your API key is stored in macOS Keychain and can be removed in settings.

### Quick start

#### 1. Download and install the DMG

The current DMG supports **Apple Silicon (M-series) Macs running macOS 14 or later**. It does not support Intel Macs. You do not need Xcode or a compiler to install the app.

1. Open this repository's **Releases** page and download **`LocalTranscriber-v1.2.0-macOS-arm64.dmg`** from the **v1.2.0 Assets** section.
2. Double-click the DMG to open the “听写” disk image.
3. Drag **`听写.app`** onto the **Applications** shortcut in the same window. Wait for copying to finish.
4. Eject the “听写” disk image in Finder, then open “听写” from your Mac's Applications folder.
5. Configure your own OpenAI API key as described below.

**Upgrading from an earlier version:** Quit the running app first, drag the new `听写.app` into Applications, and choose **Replace** when prompted. Once copying is complete, eject the disk image and launch the new app from Applications. Replacing the app preserves local transcript history, app preferences, and the API key stored in Keychain.

**First launch:** The current app is ad hoc signed and has **not been signed with an Apple Developer ID certificate or notarized by Apple**. If macOS cannot verify the developer, and you have confirmed that the download is trustworthy and has not been tampered with, follow [Apple's instructions](https://support.apple.com/en-us/102445): open **System Settings → Privacy & Security**, choose **Open Anyway**, and follow the confirmation prompts.

#### 2. Configure your API key

Open **Settings & API Key** (“设置与 API Key” in the Chinese interface), paste an API key created on the [OpenAI platform](https://platform.openai.com/api-keys), and save it. The key's project needs available API credit and access to `gpt-transcribe`.

You do not need an `.env` file or an API key embedded in the source code.

#### 3. Start transcribing

1. **Record:** Click **Start recording** (“开始录音”), speak, then click **Stop & transcribe** (“停止并转写”).
2. **Import:** Drop an audio file, click the import area, or use **Import audio** (“导入音频”). Check the selected file, then click **Transcribe** (“转写音频”).
3. **Review:** Edit the transcript and press `⌘S` to save. Changes are also saved when switching records or quitting normally.
4. **Export:** Copy the text or press `⌘⇧E` to export a TXT file.

The app uses the microphone only after you start recording. It does not capture system audio.

#### 4. Switch the interface language

Choose **简体中文** or **English** from **“界面语言 / Interface language”** at the bottom of the sidebar or in settings. The change takes effect immediately without restarting, and your choice is restored on subsequent launches. On first launch, a Chinese system preferred language selects Simplified Chinese; all other languages select English.

Interface language is independent of **Audio language** (“音频语言”): the former controls app-owned interface text, messages, and menus, while the latter provides a hint about the language spoken in the recording. Switching the interface language does not translate or modify transcript history, filenames, user-entered titles, or other input. Native macOS menus and system permission prompts continue to follow the system language.

### Model, formats, and accuracy

The app uses **`gpt-transcribe`** and does not automatically switch models. Based on the [OpenAI speech-to-text guide](https://developers.openai.com/api/docs/guides/speech-to-text) and [model documentation](https://developers.openai.com/api/docs/models/gpt-transcribe), checked on **October 23, 2026**, this is the officially recommended model for high-accuracy file transcription. Noise, accents, overlapping speakers, and specialist terminology can still affect results. Review important transcripts manually.

- Transcripts preserve the original language. The app does not translate or call a separate text model to rewrite the result.
- Keywords and recording context entered under **Improve recognition accuracy** (“提升识别准确度”) are sent with the transcription request. Use them for relevant names, brands, abbreviations, and background.
- MP3, M4A, WAV, MP4, MPEG, MPGA, FLAC, OGG, and WebM files up to **24 MB** can be uploaded directly.
- Larger files and other importable media formats are converted to M4A using native macOS components and split into segments of up to **10 minutes**. Segments are split further if needed to meet the size limit.
- Conversion requires macOS to be able to decode the source. If a file cannot be read, convert it to M4A, MP3, or WAV first. Video files must contain a usable audio track.
- Segment boundaries may fall within sentences; review transitions between segments. The current version does not provide speaker identification, subtitle timestamps, or live word-by-word transcription.

### Privacy and storage

**Uploads:** Only when transcription starts, the selected audio or recording and your language, keyword, and context hints are sent directly to OpenAI. The app has no intermediary server or telemetry.

**API key:** Stored in macOS Keychain under the service `com.localtranscriber.mac`. It is not written to source code, UserDefaults, logs, or transcript history. Keychain synchronization is not enabled.

**Transcript history:** Stored at `~/Library/Application Support/LocalTranscriber/history.json`, with a limit of 100 records. Directory permissions are `0700` and file permissions are `0600`; history is stored as local plaintext. Interface language, audio language, keywords, and recording context are stored in the app's local preferences.

**Audio files:** Original imported files are never modified or deleted. Temporary recordings are deleted after successful transcription, when discarded, when switching tasks, or on normal exit. They are retained after failure or cancellation so you can retry. Temporary conversion and upload copies are cleaned up after processing; a crash or forced quit may leave temporary files.

**Interruptions and retries:** Partial text is saved after each completed segment. Retrying processes the entire recording again, creates a new record, and incurs additional API charges. Earlier partial results are preserved. If microphone recording is interrupted unexpectedly, the app attempts to retain the usable audio.

### Keyboard shortcuts

- `⌘N`: New transcription
- `⌘O`: Import audio
- `⌘⇧R`: Start recording / Stop and transcribe
- `⌘S`: Save edits
- `⌘⇧E`: Export text
- `⌘,`: Settings

### Development and validation

The project uses Swift Package Manager, SwiftUI for the interface, AVFoundation for audio processing, and the Security framework for key storage.

#### Build from source

Requires **macOS 14 or later** and Xcode or Command Line Tools with **Swift 6**. Check your toolchain with `swift --version`.

```sh
git clone <repository-url> local-transcriber
cd local-transcriber
bash scripts/build-app.sh
open "dist/听写.app"
```

Replace `<repository-url>` with this repository's GitHub clone URL. The build script generates:

- `dist/听写.app`: The app bundle you can run locally.
- `dist/LocalTranscriber-macOS.zip`: A ZIP archive of the app.
- `dist/LocalTranscriber-v1.2.0-macOS-arm64.dmg`: The versioned DMG installer.
- `dist/LocalTranscriber-macOS-arm64.dmg`: A copy of the same installer with a stable filename for existing download links.

The DMG filenames above apply to an Apple Silicon build. The script builds for the current Mac's architecture and does not produce a Universal Binary. It reads the version and architecture from the app to name the DMG, applies an ad hoc signature to the app, and automatically generates the ZIP and DMG.

To repackage an existing `dist/听写.app` without rebuilding, run:

```sh
bash scripts/build-dmg.sh
```

This command verifies and preserves the existing app signature; it does not recompile or re-sign the app.

#### Project structure and tests

```text
.
├── Package.swift
├── Sources/
│   ├── LocalTranscriber/       # UI, recording, import, preprocessing, local storage
│   └── TranscriberCore/        # OpenAI requests, validation, errors, cancellation
├── Tests/
│   ├── LocalTranscriberTests/  # Imports, state, history, interface localization
│   └── TranscriberCoreTests/   # Mock API request tests
├── Resources/                 # App metadata and signing entitlements
└── scripts/                   # App packaging and icon generation
```

Run tests from the repository root. They do not require an API key and do not make real API requests:

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache" \
swift test --disable-sandbox
```

All 40 automated tests for version **1.2.0** have passed: 7 file import tests, 9 local state and history tests, 11 mocked transcription API tests, and 13 interface localization tests. Automated tests do not call the live OpenAI API. Real microphone recording and live API transcription still need to be verified after configuring a key and granting permission.

#### Publish to GitHub Releases

When creating a release on the GitHub website, use **`v1.2.0`** as the recommended tag. Attach `dist/LocalTranscriber-v1.2.0-macOS-arm64.dmg` and copy both languages from [RELEASE_NOTES.md](RELEASE_NOTES.md) into the release description. To preserve download links that use the stable asset name, also attach `dist/LocalTranscriber-macOS-arm64.dmg`. Wait for the asset uploads to finish before publishing. The DMG contains `听写.app` and an Applications shortcut for drag-and-drop installation.

If you later complete Developer ID signing and Apple notarization, repackage the final app with `bash scripts/build-dmg.sh`, upload the resulting DMG, and update the signing status in both the README and release notes. Signing and notarization must follow the build. Do not rerun `build-app.sh` afterward, because it overwrites the signature.

### Troubleshooting

**Swift is missing or the toolchain is too old**

Install Xcode or Command Line Tools containing Swift 6, check `swift --version`, and run the build script again.

**Invalid API key, insufficient credit, or unavailable model**

Check the key's OpenAI project, API credit, and model access. The app displays the error and does not fall back to another model.

**Recording fails or microphone permission is missing**

Allow “听写” under **System Settings → Privacy & Security → Microphone**. Launch the built `.app` so macOS can identify its permission request, and check that an input device is available.

**A file cannot be imported or converted**

Import one nonempty audio or video file that has been downloaded to your Mac. Folders, shortcuts, and web URLs cannot be imported directly. If decoding fails, convert the file to M4A, MP3, or WAV first.

**Network error or interrupted transcription**

Check the network connection and macOS proxy settings, then retry the retained audio. Completed segments remain saved. Retrying transcribes the full audio again.

**Transcript history cannot be saved**

Copy or export the current text first, then check disk space and the history directory's permissions. The app blocks navigation that would discard unsaved edits. If the directory is inaccessible, fix its permissions and restart the app.
