# 听写 · Local Transcriber

**用自己的 OpenAI API Key，把录音和音频文件转成文字。**

听写是一款轻量的原生 macOS 应用，使用 SwiftUI 构建，固定调用 OpenAI `gpt-transcribe` 模型。适合整理口述、访谈、会议录音和学习笔记：录音或导入文件，转写后直接校对、复制、导出。

Native macOS speech-to-text app powered by your OpenAI API key.

> **本地客户端，云端转写。** 应用在 Mac 上运行；发起转写时，音频会直接上传至 OpenAI。需要网络及可用的 OpenAI API 额度，API 费用由你的账户承担。

## 功能

- **原生轻量**：SwiftUI + macOS 系统框架，无第三方依赖，无需 Electron 或 Python 运行时；本机构建的 App 约 2 MB，实际大小随架构和工具链变化。
- **麦克风录音**：点击开始，停止后转写；首次使用由系统请求麦克风权限。
- **拖拽或点击导入**：把文件拖入虚线区域，拖入时高亮；也可点击区域或“选择文件”。每次导入一个文件，导入本身不会上传音频。
- **长音频处理**：超出本地上传阈值时自动转换、分段并依次转写，展示处理进度，可取消。
- **语言与术语提示**：自动识别语言，也可指定普通话、英语、中英混合、粤语或日语，补充专有名词与录音背景。
- **编辑与导出**：在应用内修改转写文字，一键复制或导出 UTF-8 TXT。
- **本地历史**：保留最近 100 条记录，支持搜索、重命名和删除，逐段保存已完成的文字。
- **钥匙串保存密钥**：API Key 存放在 macOS 钥匙串，可在设置中移除。

## 快速开始

### 1. 从源码构建

需要 **macOS 14 或更新版本**，以及包含 **Swift 6** 的 Xcode 或 Command Line Tools。可先用 `swift --version` 确认工具链版本。

```sh
git clone <仓库地址> local-transcriber
cd local-transcriber
./scripts/build-app.sh
open "dist/听写.app"
```

将 `<仓库地址>` 替换为本仓库的 GitHub 克隆地址。仓库提供源码，`dist` 由构建脚本生成。

构建成功后会得到：

- `dist/听写.app`：可双击运行，也可以拖入“应用程序”。
- `dist/LocalTranscriber-macOS.zip`：打包后的 App。

脚本默认构建当前 Mac 的架构，不生成 Universal Binary。生成的应用采用本地临时签名（ad hoc），尚未使用 Apple Developer ID 签名或公证；面向其他 Mac 正式分发时需要完成相应签名与公证。

### 2. 配置 API Key

打开“设置与 API Key”，粘贴在 [OpenAI 平台](https://platform.openai.com/api-keys) 创建的 API Key，然后保存。密钥所属项目需要有可用额度和 `gpt-transcribe` 模型访问权限。

无需创建 `.env`，也无需把密钥写入源码。

### 3. 开始转写

1. **录音**：点击“开始录音”，讲话结束后点击“停止并转写”。
2. **文件**：拖入音频、点击导入区域或使用“导入音频”菜单，确认文件后点击“转写音频”。
3. **校对**：编辑结果后按 `⌘S` 保存；切换记录或正常退出时也会保存修改。
4. **导出**：复制文字，或按 `⌘⇧E` 导出 TXT。

应用只在你点击录音按钮后使用麦克风，不采集系统声音。

## 模型、格式与准确度

应用固定使用 **`gpt-transcribe`**，不会自动切换到其他模型。根据 2026-10-23 核对的 [OpenAI 文件转写指南](https://developers.openai.com/api/docs/guides/speech-to-text) 和 [模型说明](https://developers.openai.com/api/docs/models/gpt-transcribe)，它是官方推荐的高准确度文件转写模型。实际效果仍受噪音、口音、重叠说话和专业术语影响，重要内容应人工校对。

- 保留原始语言，不自动翻译，也不额外调用文本模型改写结果。
- “提升识别准确度”中的关键词和录音背景会随转写请求发送，适合填写人名、品牌名、缩写等录音相关信息。
- 不超过 **24 MB** 的 MP3、M4A、WAV、MP4、MPEG、MPGA、FLAC、OGG 和 WebM 可直接上传。
- 较大文件及其他可导入的媒体格式，由 macOS 原生组件转换为 M4A，并按最长 **10 分钟** 分段；必要时继续细分，以满足大小限制。
- 转换需要 macOS 能解码源文件。若无法读取，请先转为 M4A、MP3 或 WAV；视频文件需要包含可用音轨。
- 分段切点可能落在句中，建议复核段落衔接处。当前版本不提供说话人区分、字幕时间轴或实时逐字转写。

## 隐私与数据保存

**上传内容**：仅在发起转写时，将所选音频或录音及填写的语言、关键词、背景提示直接发送至 OpenAI。应用没有自建中转服务，也不包含遥测。

**API Key**：保存在 macOS 钥匙串，service 为 `com.localtranscriber.mac`。不写入源码、UserDefaults、日志或转写历史，不启用钥匙串同步。

**转写历史**：保存在 `~/Library/Application Support/LocalTranscriber/history.json`，最多保留最近 100 条。目录权限为 `0700`，文件权限为 `0600`；历史是本机明文文件。语言、关键词和背景提示保存在本机应用设置中。

**音频文件**：导入的原始文件不修改、不删除。临时录音在成功转写、放弃、切换任务或正常退出时删除；失败或取消后保留，以便重试。转换及上传使用的临时副本会在处理结束后清理，强制退出或崩溃可能留下系统临时文件。

**中断与重试**：每完成一段都会保存部分文字。重试会重新处理完整音频、创建新记录，并产生相应 API 费用；之前保存的部分结果不会被覆盖。麦克风意外中断时，应用会尽可能保留可用录音。

## 快捷键

- `⌘N`：新建转写
- `⌘O`：导入音频
- `⌘⇧R`：开始录音 / 停止并转写
- `⌘S`：保存编辑
- `⌘⇧E`：导出文本
- `⌘,`：设置

## 开发与验证

使用 Swift Package Manager 管理项目，界面基于 SwiftUI，音频处理使用 AVFoundation，密钥存储使用 Security 框架。

```text
.
├── Package.swift
├── Sources/
│   ├── LocalTranscriber/       # 界面、录音、导入、预处理与本地存储
│   └── TranscriberCore/        # OpenAI 请求、参数校验、错误及取消处理
├── Tests/
│   ├── LocalTranscriberTests/  # 文件导入、编辑状态与历史记录测试
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

当前版本 **1.1.0** 包含 27 项自动测试：7 项文件导入测试、9 项本地状态与历史测试、11 项转写 API 测试。已完成本地构建、自动测试、界面检查，以及合成音频转换和分段验证；真实麦克风录音与真实 OpenAI API 转写仍需在配置密钥和授权后验证。

## 常见问题

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
