import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

private let ink = Color(red: 0.18, green: 0.19, blue: 0.23)
private let accent = Color(red: 0.39, green: 0.35, blue: 0.76)
private let paper = Color(red: 0.98, green: 0.975, blue: 0.96)

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: AudioRecorder
    @ObservedObject var history: HistoryStore
    @State private var showContext = false
    @State private var search = ""
    @State private var deleting: TranscriptRecord?
    @State private var isAudioDropTargeted = false

    private var highlightsAudioDrop: Bool { isAudioDropTargeted && !model.isWorking }

    private var filteredRecords: [TranscriptRecord] {
        search.isEmpty ? history.records : history.records.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 235)
            Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1)
            mainContent
        }
        .background(paper)
        .foregroundStyle(ink)
        .tint(accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .onChange(of: recorder.recoveredRecordingURL) { _, url in
            if url != nil { model.recoverRecording() }
        }
        .alert("删除这条转写？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                if let record = deleting { model.deleteRecord(record) }
                deleting = nil
            }
        } message: { Text("本机保存的这条文字记录将被删除。") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent).frame(width: 38, height: 38)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("听写").font(.system(size: 21, weight: .semibold))
                    Text("LOCAL TRANSCRIBER").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                        .foregroundStyle(.secondary)
                }
            }.padding(.top, 24)

            Button { model.newTranscript() } label: {
                HStack { Image(systemName: "plus"); Text("新的转写"); Spacer(); Text("⌘N").opacity(0.55) }
                    .font(.system(size: 12, weight: .medium)).padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.07)))
            }.buttonStyle(.plain).disabled(model.isWorking)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("最近转写").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(history.records.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
                if !history.records.isEmpty {
                    TextField("搜索文字…", text: $search)
                        .textFieldStyle(.roundedBorder).font(.system(size: 11))
                }
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if history.records.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("让声音留下来").font(.system(size: 12, weight: .medium))
                                Text("完成的转写会出现在这里，\n随时查阅、编辑或导出。")
                                    .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                        }
                        ForEach(filteredRecords) { record in
                            Button { model.selectRecord(record) } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(record.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text(record.text).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(11)
                                .background(model.selectedRecordID == record.id ? accent.opacity(0.08) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).disabled(model.isWorking)
                                .contextMenu {
                                    Button("删除记录", role: .destructive) { deleting = record }.disabled(model.isWorking)
                                }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Divider()
            Button { model.showSettings = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape").font(.system(size: 14))
                    Text("设置与 API Key").font(.system(size: 12))
                    Spacer()
                    Circle().fill(model.hasAPIKey ? Color.green.opacity(0.8) : Color.orange).frame(width: 6, height: 6)
                }.foregroundStyle(.secondary)
            }.buttonStyle(.plain)
            Label("文字仅保存在这台 Mac", systemImage: "internaldrive")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18).padding(.bottom, 20)
        .background(Color(red: 0.95, green: 0.945, blue: 0.93))
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("把声音，变成文字。").font(.system(size: 25, weight: .semibold))
                    Text("专注表达，让听写记下每一个细节。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Label("GPT-Transcribe", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(accent)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(accent.opacity(0.07), in: Capsule())
            }.padding(.top, 24)

            if !model.hasAPIKey {
                HStack(spacing: 10) {
                    Image(systemName: "key.horizontal").foregroundStyle(accent)
                    Text("先添加你的 OpenAI API Key，即可开始转写。")
                        .font(.system(size: 12))
                    Spacer()
                    Button("添加密钥") { model.showSettings = true }.buttonStyle(.bordered)
                }.padding(12).background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            captureCard

            DisclosureGroup(isExpanded: $showContext) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("专有名词").font(.system(size: 11, weight: .medium))
                    TextField("人名、产品名、医学术语… 用逗号分隔", text: $model.keywords)
                        .textFieldStyle(.roundedBorder)
                    Text("录音背景").font(.system(size: 11, weight: .medium))
                    TextField("例如：一场关于糖尿病随访的中英双语访谈", text: $model.context)
                        .textFieldStyle(.roundedBorder)
                    Text("仅填写音频中可能出现的词，有助于提高识别准确度。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.font(.system(size: 12)).padding(.top, 12)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "slider.horizontal.3")
                    Text("提升识别准确度")
                    Text("可选").foregroundStyle(.tertiary)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.disabled(model.isWorking)

            if let message = model.errorMessage ?? recorder.errorMessage ?? history.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(message).textSelection(.enabled)
                    Spacer(minLength: 0)
                    if model.errorMessage != nil {
                        Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }
                }.font(.system(size: 11)).foregroundStyle(Color(red: 0.7, green: 0.24, blue: 0.17))
                    .padding(12).background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }

            transcriptCard

            HStack {
                Circle().fill(model.isWorking ? accent : Color.green.opacity(0.7)).frame(width: 5, height: 5)
                Text(model.notice ?? model.status).lineLimit(1)
                Spacer()
                Text("音频发送至 OpenAI · 需联网").foregroundStyle(.tertiary)
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.bottom, 16)
        }.padding(.horizontal, 30).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var captureCard: some View {
        VStack(spacing: 18) {
            Button { model.importAudio() } label: {
              HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(accent.opacity(0.07)).frame(width: 62, height: 62)
                    if recorder.isRecording {
                        HStack(alignment: .center, spacing: 3) {
                            ForEach(0..<7) { i in
                                Capsule().fill(accent).frame(width: 3, height: 6 + CGFloat(recorder.level) * CGFloat([18, 30, 22, 42, 26, 34, 16][i]))
                            }
                        }.animation(.easeOut(duration: 0.1), value: recorder.level)
                    } else {
                        Image(systemName: highlightsAudioDrop ? "arrow.down.doc" : (model.sourceURL == nil ? "square.and.arrow.down" : "waveform"))
                            .font(.system(size: 27, weight: .light)).foregroundStyle(accent)
                    }
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(recorder.isRecording ? duration(recorder.elapsed) : (highlightsAudioDrop ? "松开以导入音频" : (model.sourceURL == nil ? "拖拽音频文件到这里" : model.sourceName)))
                        .font(.system(size: recorder.isRecording ? 25 : 16, weight: .medium, design: recorder.isRecording ? .monospaced : .default))
                        .lineLimit(1)
                    Text(recorder.isRecording ? "正在聆听 · 停止后自动转写" : (model.isImportingAudio ? "正在读取拖入的文件…" : (model.sourceURL == nil ? "或点击选择文件 · MP3、M4A、WAV 等" : "音频已就绪 · 点击或拖入其他文件可替换")))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !model.isWorking {
                    Text(model.sourceURL == nil ? "选择文件" : "更换文件")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(accent)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(accent.opacity(0.07), in: Capsule())
                }
              }.frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(model.isWorking)
                .accessibilityLabel(model.sourceURL == nil ? "音频导入区，点击选择或拖入音频文件" : "已导入 \(model.sourceName)，点击更换文件")
            HStack(spacing: 10) {
                if model.isImportingAudio {
                    ProgressView().controlSize(.small)
                    Text("正在读取拖入的文件…").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("取消导入") { model.cancelAudioImport() }.buttonStyle(.bordered)
                } else if model.isBusy {
                    ProgressView().controlSize(.small)
                    Text(model.status).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("取消") { model.cancelTranscription() }.buttonStyle(.bordered)
                } else {
                    Button { model.toggleRecording() } label: {
                        Label(recorder.isRecording ? "停止并转写" : "开始录音", systemImage: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .frame(minWidth: 92).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).tint(recorder.isRecording ? .red : accent)
                        .disabled(model.isStartingRecording || model.isImportingAudio || model.isTerminating)
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                    if recorder.isRecording {
                        Button("放弃录音") { model.discardRecording() }.buttonStyle(.borderless).foregroundStyle(.secondary)
                    } else {
                        Button { model.importAudio() } label: {
                            Label("导入音频", systemImage: "arrow.up.doc").padding(.vertical, 5)
                        }.buttonStyle(.bordered).disabled(model.isWorking)
                        if model.sourceURL != nil {
                            Button("转写音频") { model.transcribe() }.buttonStyle(.borderedProminent).disabled(!model.canTranscribe)
                        }
                    }
                    Spacer(minLength: 0)
                    if !recorder.isRecording {
                        Picker("语言", selection: $model.language) {
                            ForEach(LanguageHint.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 125).disabled(model.isWorking)
                    }
                }
            }.font(.system(size: 12, weight: .medium))
            if model.isBusy && model.progress > 0 {
                ProgressView(value: model.progress).tint(accent)
            }
            if !recorder.isRecording && !model.isBusy {
                HStack(spacing: 5) {
                    Image(systemName: "doc.badge.arrow.up")
                    Text("一次导入一个文件 · 点击“转写音频”后上传并转写")
                    Spacer(minLength: 0)
                }.font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }.padding(20)
            .background(highlightsAudioDrop ? accent.opacity(0.06) : .white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(highlightsAudioDrop ? accent : accent.opacity(model.isWorking ? 0.12 : 0.25),
                        style: StrokeStyle(lineWidth: highlightsAudioDrop ? 2 : 1, dash: model.isWorking ? [] : [6, 4])))
            .animation(.easeInOut(duration: 0.15), value: highlightsAudioDrop)
            .onDrop(of: [UTType.fileURL], isTargeted: $isAudioDropTargeted) { providers in
                model.importDroppedAudio(providers)
            }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "text.alignleft").foregroundStyle(accent)
                if model.selectedRecordID != nil {
                    TextField("标题", text: $model.draftTitle).textFieldStyle(.plain).font(.system(size: 12, weight: .medium))
                        .disabled(model.isBusy)
                } else {
                    Text("转写文字").font(.system(size: 12, weight: .medium))
                }
                Spacer()
                if model.hasEdits {
                    Button("保存") { model.saveEdits() }.font(.system(size: 11)).disabled(model.isBusy)
                }
                Button { model.copyText() } label: { Image(systemName: "doc.on.doc") }
                    .help("复制文字").accessibilityLabel("复制文字").disabled(model.draftText.isEmpty)
                Button { model.exportText() } label: { Image(systemName: "square.and.arrow.up") }
                    .help("导出 TXT").accessibilityLabel("导出文本").disabled(model.draftText.isEmpty)
            }.buttonStyle(.borderless).padding(16)
            Divider().opacity(0.6)
            ZStack(alignment: .topLeading) {
                if model.draftText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.isBusy ? "正在将声音化为文字…" : "文字会在这里慢慢展开。")
                            .font(.system(size: 18, weight: .regular, design: .serif)).foregroundStyle(ink.opacity(0.45))
                        Text(model.isBusy ? "长音频将分段处理，你可以随时取消。" : "开始一段录音，留下灵感、访谈或会议中的重要内容。")
                            .font(.system(size: 12)).foregroundStyle(ink.opacity(0.32))
                    }.padding(24).allowsHitTesting(false)
                }
                TextEditor(text: $model.draftText)
                    .font(.system(size: 15)).lineSpacing(7)
                    .scrollContentBackground(.hidden)
                    .padding(17)
                    .opacity(model.draftText.isEmpty ? 0 : 1)
                    .disabled(model.isBusy || model.selectedRecordID == nil)
                    .accessibilityLabel("转写文字")
            }.frame(minHeight: 140, maxHeight: .infinity)
            HStack {
                Text(model.hasEdits ? "有未保存修改 · ⌘S 保存" : (model.draftText.isEmpty ? "保留原始语言，不自动翻译" : "可编辑 · 切换记录时自动保存"))
                Spacer()
                Text("\(model.draftText.count) 字符").monospacedDigit()
            }.font(.system(size: 10)).foregroundStyle(.tertiary).padding(.horizontal, 16).padding(.bottom, 13)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.065)))
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return value >= 3600 ? String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var error: String?
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("连接你的 OpenAI").font(.system(size: 23, weight: .semibold))
                    Text("你的密钥，你的 Mac。") .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.tertiary) }
                    .buttonStyle(.plain).accessibilityLabel("关闭设置")
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("API KEY").font(.system(size: 10, weight: .semibold)).tracking(1)
                    Spacer()
                    if model.hasAPIKey { Label("已保存", systemImage: "checkmark.shield.fill").font(.system(size: 10)).foregroundStyle(.green) }
                }
                SecureField(model.hasAPIKey ? "输入新密钥以替换已保存的密钥" : "sk-…", text: $key)
                    .textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
                Text("密钥只存入 macOS 钥匙串，不写入项目文件或普通设置。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Link("在 OpenAI 创建 API Key ↗", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.system(size: 11))
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Label("GPT-Transcribe · 高准确度转写", systemImage: "sparkles").font(.system(size: 13, weight: .medium))
                Text("录音结束后，音频直接发送至 OpenAI。API 使用费用由你的 OpenAI 账户单独计费。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("最近 100 条文字记录保存在本机。临时录音在转写成功或放弃后删除；失败时保留到重试、切换任务或退出。导入的原始文件保持不变。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Link("查看模型说明 ↗", destination: URL(string: "https://developers.openai.com/api/docs/models/gpt-transcribe")!)
                    .font(.system(size: 11))
            }
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                if model.hasAPIKey {
                    Button("移除密钥", role: .destructive) { confirmDelete = true }.disabled(model.isWorking)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存密钥") {
                    do { try model.saveAPIKey(key); key = ""; dismiss() }
                    catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 490).background(paper).tint(accent)
        .alert("从钥匙串移除 API Key？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) { }
            Button("移除", role: .destructive) {
                do { try model.removeAPIKey() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("文字历史会保留。再次转写前需重新输入密钥。") }
    }
}
