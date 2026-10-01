import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(store: SettingsStore) {
        let host = NSHostingController(rootView: SettingsView(store: store))
        let window = NSWindow(contentViewController: host)
        window.title = "KoeType 設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}

struct SettingsView: View {
    let store: SettingsStore

    @State private var apiKey = ""
    @State private var transcriptionModel = ""
    @State private var cleanupModel = ""
    @State private var statusMessage = ""
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                SecureField("OpenAI APIキー (sk-…)", text: $apiKey)
                TextField("文字起こしモデル", text: $transcriptionModel)
                TextField("整形モデル", text: $cleanupModel)
            }
            Section {
                HStack {
                    Button("保存") { save() }
                        .keyboardShortcut(.defaultAction)
                    Button(isTesting ? "接続テスト中…" : "接続テスト") { testConnection() }
                        .disabled(isTesting)
                    Spacer()
                }
                if !statusMessage.isEmpty {
                    Text(statusMessage)
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
        .onAppear {
            apiKey = store.apiKey ?? ""
            transcriptionModel = store.transcriptionModel
            cleanupModel = store.cleanupModel
        }
    }

    private func save() {
        store.setAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        if !transcriptionModel.trimmingCharacters(in: .whitespaces).isEmpty {
            store.transcriptionModel = transcriptionModel.trimmingCharacters(in: .whitespaces)
        }
        if !cleanupModel.trimmingCharacters(in: .whitespaces).isEmpty {
            store.cleanupModel = cleanupModel.trimmingCharacters(in: .whitespaces)
        }
        statusMessage = "保存しました。"
    }

    private func testConnection() {
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
