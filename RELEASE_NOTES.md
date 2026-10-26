# 听写 · Local Transcriber v1.2.0

[简体中文](#简体中文) · [English](#english)

## 简体中文

轻量的原生 macOS 语音转文字工具，使用自己的 OpenAI API Key，通过 `gpt-transcribe` 转写录音和音频文件。

### v1.2.0 新增：中英文界面切换

- 在侧栏或设置中的 **“界面语言 / Interface language”** 选择 **“简体中文”** 或 **“English”**，立即切换，无需重启。
- 语言选择会保存在本机，后续启动自动恢复。首次启动时，系统首选语言为中文则使用简体中文，其余语言使用 English。
- 应用自有界面、提示和菜单支持中英文；macOS 原生菜单及系统授权提示仍遵循系统语言设置。
- 界面语言与 **“音频语言 / Audio language”** 独立。切换界面语言不会翻译或修改历史正文、文件名、用户标题及其他输入内容，也不会改变所选音频语言。
- 构建脚本自动生成 App、ZIP、带版本号的 DMG 和固定文件名副本；`build-dmg.sh` 可重新封装已有 App，并保留其签名。

### 下载、安装与升级

适用于 **macOS 14 或更新版本的 Apple Silicon Mac（arm64）**。此安装包不支持 Intel Mac。

1. 在此 Release 下方的 **Assets** 中下载 **`LocalTranscriber-v1.2.0-macOS-arm64.dmg`**。
2. 如已安装旧版，先退出正在运行的听写。双击下载的 DMG，打开磁盘映像。
3. 将 **听写.app** 拖入同一窗口中的 **Applications（应用程序）** 快捷方式；升级时选择“替换”。
4. 等待复制完成，然后在 Finder 中推出磁盘映像。
5. 从 Mac 的“应用程序”文件夹启动“听写”。
6. 打开“设置与 API Key”，填写并保存你自己的 [OpenAI API Key](https://platform.openai.com/api-keys)。

替换 App 会保留本机历史记录、应用设置和钥匙串中的 API Key；升级后无需重新创建记录。若使用英文界面，第 6 步对应 **Settings & API Key**。

安装包采用本地临时签名（ad hoc），**尚未经过 Apple Developer ID 签名或公证**，macOS 可能会阻止首次打开。在确认下载来源可信且未被篡改后，可按 [Apple 官方指引](https://support.apple.com/zh-cn/102445)，到“系统设置 → 隐私与安全性”中选择“仍要打开”，再按提示确认。

### 持续提供的功能

- 麦克风录音，点击“停止并转写”后生成文字。
- 将音频拖入导入区域，或点击区域、“选择文件”导入；拖入时显示高亮提示。
- 导入后点击“转写音频”开始处理，导入本身不会上传文件。
- 长音频自动转换、分段和依次转写，支持取消。
- 可设置语言、关键词和录音背景，帮助识别专有名词。
- 在应用内编辑、复制文字，或导出为 UTF-8 TXT。
- 最近 100 条转写记录保存在本机，支持搜索、重命名和删除。

### 使用与隐私

**本地客户端，云端转写。** 应用在 Mac 上运行；发起转写时，音频及填写的语言、关键词、背景提示会直接发送至 OpenAI，需要联网。API 费用由你的 OpenAI 账户承担，所用项目需要有可用额度和模型访问权限。

API Key 保存在 **macOS 钥匙串**中。转写历史以明文保存在本机。导入的原始文件不会被修改或删除；应用不包含遥测或自建中转服务。

首次录音时需允许麦克风权限。应用只录制麦克风输入，不采集系统声音。转写准确度会受到录音质量、噪音和口音影响，重要内容请校对后使用。

### 验证情况

40 项自动测试已通过，包含 7 项文件导入、9 项本地状态与历史记录、11 项模拟 API 请求，以及本版新增的 13 项界面本地化测试。自动测试不调用真实 OpenAI API；真实麦克风录音和真实 API 转写仍需在配置密钥并授权后验证。

## English

A lightweight native macOS speech-to-text app that uses your own OpenAI API key and `gpt-transcribe` to transcribe microphone recordings and audio files.

### New in v1.2.0: Chinese and English interface switching

- Choose **简体中文** or **English** from **“界面语言 / Interface language”** in the sidebar or settings. The interface changes immediately without restarting.
- Your choice is saved locally and restored on subsequent launches. On first launch, a Chinese system preferred language selects Simplified Chinese; all other languages select English.
- App-owned interface text, messages, and menus support both languages. Native macOS menus and system permission prompts continue to follow the system language.
- Interface language is independent of **Audio language** (“音频语言”). Switching the interface does not translate or modify transcript history, filenames, user-entered titles, or other input, and it does not change the selected audio language.
- The build script automatically creates the app, ZIP, versioned DMG, and a copy with a stable filename. `build-dmg.sh` can repackage an existing app while preserving its signature.

### Download, install, and upgrade

Requires **macOS 14 or later on an Apple Silicon Mac (arm64)**. This installer does not support Intel Macs.

1. Under **Assets** below this release, download **`LocalTranscriber-v1.2.0-macOS-arm64.dmg`**.
2. If an earlier version is installed, quit the running app first. Double-click the downloaded DMG to open the disk image.
3. Drag **听写.app** into the **Applications** shortcut in the same window. When upgrading, choose **Replace**.
4. Wait for copying to finish, then eject the disk image in Finder.
5. Launch **听写** from your Mac's **Applications** folder.
6. Open **Settings & API Key**, enter your own [OpenAI API key](https://platform.openai.com/api-keys), and save it.

Replacing the app preserves local transcript history, app preferences, and your API key in Keychain. You do not need to recreate your records after upgrading. In the Chinese interface, the option in step 6 is **“设置与 API Key”**.

The app uses a local ad hoc signature and **has not been signed with an Apple Developer ID or notarized by Apple**. macOS may block it from opening the first time. After confirming that the download comes from a trusted source and has not been tampered with, follow [Apple's guidance](https://support.apple.com/en-us/102445): open **System Settings → Privacy & Security**, choose **Open Anyway** (“仍要打开” on a Chinese-language Mac), and follow the confirmation prompts.

### Existing features

- Record through your microphone, then click **Stop & transcribe** (“停止并转写”) to generate text.
- Drag an audio file into the import area, click the area, or use **Choose file** (“选择文件”). The area highlights when you drag a file over it.
- After importing, click **Transcribe** (“转写音频”) to start processing. Importing a file alone does not upload it.
- Automatically convert, split, and transcribe long audio in sequence, with cancellation support.
- Provide language hints, keywords, and recording context to help with names and specialized terms.
- Edit and copy the transcript in the app, or export it as a UTF-8 TXT file.
- Keep the latest 100 transcripts locally, with search, renaming, and deletion.

### Usage and privacy

**Local app, cloud transcription.** The app runs on your Mac. When you start transcription, the audio and any language hints, keywords, and context you provide are sent directly to OpenAI. An internet connection is required. API usage is billed to your OpenAI account, and your project must have available API credit and access to the model.

Your API key is stored in **macOS Keychain**. Transcript history is stored locally in plain text. Imported original files are not modified or deleted. The app includes no telemetry or developer-operated relay service.

Microphone access is requested before the first recording. The app records microphone input only; it does not capture system audio. Transcription accuracy depends on recording quality, noise, and accents. Review important content before using it.

### Validation

All 40 automated tests have passed: 7 file import tests, 9 local state and history tests, 11 mocked API request tests, and 13 interface localization tests added in this version. Automated tests do not call the live OpenAI API. Real microphone recording and live API transcription still need to be verified after configuring an API key and granting microphone access.
