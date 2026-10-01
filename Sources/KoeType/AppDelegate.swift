import AppKit
import AVFoundation

enum AppPhase {
    case idle
    case recording
    case processing
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var phase: AppPhase = .idle

    private var menuBar: MenuBarController!
    private let hotkeys = HotkeyManager()
    private let recorder = AudioRecorder()
    private let settings = SettingsStore()
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(
            onToggle: { [weak self] in self?.toggleRecording() },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        hotkeys.onToggle = { [weak self] in self?.toggleRecording() }
        hotkeys.onCancel = { [weak self] in self?.cancelRecording() }
        hotkeys.registerToggleHotkey()
        recorder.onMaxDurationReached = { [weak self] in self?.toggleRecording() }

        Notifier.requestAuthorization()
        _ = TextInserter.ensureAccessibilityPermission(prompt: true)
        if (settings.apiKey ?? "").isEmpty {
            openSettings()
        }
    }

    // MARK: - Recording flow

    func toggleRecording() {
        switch phase {
        case .idle:
            startRecording()
        case .recording:
            stopAndProcess()
        case .processing:
            break // 処理完了までは新しい録音を受け付けない
        }
    }

    private func startRecording() {
        guard (settings.apiKey ?? "").isEmpty == false else {
            Notifier.notify(title: "APIキーが未設定です",
                            body: "設定画面でOpenAIのAPIキーを入力してください。")
            openSettings()
            return
        }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    Notifier.notify(title: "マイクへのアクセスが許可されていません",
                                    body: "システム設定 > プライバシーとセキュリティ > マイク で KoeType を許可してください。")
                    return
                }
                self.beginRecordingSession()
            }
        }
    }

    private func beginRecordingSession() {
        guard phase == .idle else { return }
        do {
            try recorder.start()
        } catch {
            Notifier.notify(title: "録音を開始できませんでした", body: error.localizedDescription)
            return
        }
        phase = .recording
        menuBar.update(phase: .recording)
        hotkeys.setEscEnabled(true)
        NSSound(named: "Pop")?.play()
    }

    private func cancelRecording() {
        guard phase == .recording else { return }
        recorder.cancel()
        hotkeys.setEscEnabled(false)
        phase = .idle
        menuBar.update(phase: .idle)
        NSSound(named: "Basso")?.play()
    }

    private func stopAndProcess() {
        guard phase == .recording else { return }
        hotkeys.setEscEnabled(false)
        NSSound(named: "Bottle")?.play()
        guard let audioURL = recorder.stop() else {
            phase = .idle
            menuBar.update(phase: .idle)
            return
        }
        // 0.5秒未満相当(16kHz 16bit mono ≒ 32KB/s)は無音扱い
        let attributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard byteCount > 16_000 else {
            try? FileManager.default.removeItem(at: audioURL)
            Notifier.notify(title: "録音が短すぎます", body: "もう一度お試しください。")
            phase = .idle
            menuBar.update(phase: .idle)
            return
        }

        phase = .processing
        menuBar.update(phase: .processing)
        let apiKey = settings.apiKey ?? ""
        let transcriptionModel = settings.transcriptionModel
        let cleanupModel = settings.cleanupModel

        Task {
            defer { try? FileManager.default.removeItem(at: audioURL) }
            do {
                let raw = try await TranscriptionService(apiKey: apiKey, model: transcriptionModel)
                    .transcribe(fileURL: audioURL)
                let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedRaw.isEmpty else {
                    await self.finish(notice: ("音声を認識できませんでした", "もう一度お試しください。"))
                    return
                }

                var cleaned: String
                do {
                    cleaned = try await CleanupService(apiKey: apiKey, model: cleanupModel)
                        .clean(trimmedRaw)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } catch {
                    // 整形に失敗しても文字起こし結果は失わせない
                    cleaned = trimmedRaw
                    Notifier.notify(title: "AI整形に失敗しました",
                                    body: "文字起こし結果をそのまま挿入します。(\(error.localizedDescription))")
                }

                guard !cleaned.isEmpty else {
                    // 整形モデルが「意味のある内容なし」と判断
                    await self.finish(notice: ("挿入する内容がありませんでした", "フィラーのみの発話と判断されました。"))
                    return
                }
                let result = cleaned
                await MainActor.run {
                    TextInserter.insert(result)
                    self.finish()
                }
            } catch {
                await self.finish(notice: ("音声入力に失敗しました", error.localizedDescription))
            }
        }
    }

    @MainActor
    private func finish(notice: (title: String, body: String)? = nil) {
        if let notice {
            Notifier.notify(title: notice.title, body: notice.body)
        }
        phase = .idle
        menuBar.update(phase: .idle)
    }

    // MARK: - Settings

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(store: settings)
        }
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
