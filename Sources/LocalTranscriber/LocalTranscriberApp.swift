import SwiftUI
import AppKit

@main
struct LocalTranscriberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window(model.t("听写 · Local Transcriber"), id: "main") {
            ContentView(model: model, recorder: model.recorder, history: model.history)
                .onAppear { delegate.model = model }
                .frame(minWidth: 940, minHeight: 700)
        }
        .defaultSize(width: 1120, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.t("新建转写")) { model.newTranscript() }.keyboardShortcut("n")
                    .disabled(model.isWorking)
                Button(model.t("导入音频…")) { model.importAudio() }.keyboardShortcut("o")
                    .disabled(model.isWorking)
            }
            CommandGroup(replacing: .appSettings) {
                Button(model.t("设置…")) { model.showSettings = true }.keyboardShortcut(",")
            }
            CommandGroup(replacing: .saveItem) {
                Button(model.t("保存修改")) { model.saveEdits() }.keyboardShortcut("s")
                    .disabled(model.selectedRecordID == nil || model.isBusy)
                Button(model.t("导出文本…")) { model.exportText() }.keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.draftText.isEmpty)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let model, model.isWorking {
            let alert = NSAlert()
            alert.messageText = model.t("结束当前任务并退出？")
            alert.informativeText = model.t("进行中的录音或转写会停止。已生成的文字会保存在本机。")
            alert.addButton(withTitle: model.t("继续使用"))
            alert.addButton(withTitle: model.t("结束并退出"))
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        }
        guard model?.saveEdits() != false else { return .terminateCancel }
        Task { @MainActor in
            let canQuit = await model?.shutdown() ?? true
            NSApp.reply(toApplicationShouldTerminate: canQuit)
        }
        return .terminateLater
    }
}
