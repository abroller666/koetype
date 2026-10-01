import AppKit
import Combine
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(store: SettingsStore) {
        let host = NSHostingController(rootView: SettingsView(model: SettingsViewModel(store: store)))
        let window = NSWindow(contentViewController: host)
        window.title = "KoeType 設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}

/// macOS 27 SDK では `@State` が SwiftUIMacros(Xcode 同梱のみ)のマクロになったため、
/// Command Line Tools でもビルドできるよう ObservableObject で状態を保持する。
@MainActor
final class SettingsViewModel: ObservableObject {
    private let store: SettingsStore

    @Published var apiKey = ""
    @Published var transcriptionModel = ""
    @Published var cleanupModel = ""
    @Published var statusMessage = ""
    @Published var isTesting = false

    init(store: SettingsStore) {
        self.store = store
    }

    func load() {
        apiKey = store.apiKey ?? ""
        transcriptionModel = store.transcriptionModel
        cleanupModel = store.cleanupModel
    }

    func save() {
        store.setAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        if !transcriptionModel.trimmingCharacters(in: .whitespaces).isEmpty {
            store.transcriptionModel = transcriptionModel.trimmingCharacters(in: .whitespaces)
        }
        if !cleanupModel.trimmingCharacters(in: .whitespaces).isEmpty {
            store.cleanupModel = cleanupModel.trimmingCharacters(in: .whitespaces)
        }
        statusMessage = "保存しました。"
    }

    func testConnection() {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            statusMessage = "APIキーを入力してください。"
            return
        }
        isTesting = true
        statusMessage = ""
        Task {
            defer { isTesting = false }
            do {
                var request = URLRequest(url: OpenAIAPI.baseURL.appendingPathComponent("models"))
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                try OpenAIAPI.checkResponse(response, data: data)
                statusMessage = "接続成功。APIキーは有効です。"
            } catch {
                statusMessage = "接続失敗: \(error.localizedDescription)"
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        Form {
            Section {
                SecureField("OpenAI APIキー (sk-…)", text: $model.apiKey)
                TextField("文字起こしモデル", text: $model.transcriptionModel)
                TextField("整形モデル", text: $model.cleanupModel)
            }
            Section {
                HStack {
                    Button("保存") { model.save() }
                        .keyboardShortcut(.defaultAction)
                    Button(model.isTesting ? "接続テスト中…" : "接続テスト") { model.testConnection() }
                        .disabled(model.isTesting)
                    Spacer()
                }
                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("使い方: ⌥Space で録音開始 → もう一度 ⌥Space で停止すると、フィラー除去済みのテキストがカーソル位置に挿入されます。録音中は Esc でキャンセル。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.load() }
    }
}
