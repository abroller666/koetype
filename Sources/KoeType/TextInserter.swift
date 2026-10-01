import AppKit
import ApplicationServices

/// ペーストボード経由で、フォーカス中アプリのカーソル位置にテキストを挿入する。
enum TextInserter {
    static func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard ensureAccessibilityPermission(prompt: false) else {
            Notifier.notify(title: "クリップボードにコピーしました",
                            body: "アクセシビリティ権限がないため自動挿入できません。⌘V で貼り付けてください。システム設定 > プライバシーとセキュリティ > アクセシビリティ で KoeType を許可すると自動挿入されます。")
            return
        }

        postCommandV()

        // 貼り付け完了後に元のクリップボード内容を復元する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let saved {
                pasteboard.setString(saved, forType: .string)
            }
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // kVK_ANSI_V
        keyVDown?.flags = .maskCommand
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
}
