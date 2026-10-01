import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let toggleItem: NSMenuItem
    private let onToggle: () -> Void
    private let onOpenSettings: () -> Void

    init(onToggle: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onOpenSettings = onOpenSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem = NSMenuItem(title: "録音を開始", action: #selector(toggleAction), keyEquivalent: "")
        super.init()

        let menu = NSMenu()
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem(title: "ホットキー: ⌥Space(録音中は Esc でキャンセル)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "設定…", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "KoeType を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        update(phase: .idle)
    }

    func update(phase: AppPhase) {
        guard let button = statusItem.button else { return }
        switch phase {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "KoeType 待機中")
            button.contentTintColor = nil
            toggleItem.title = "録音を開始"
            toggleItem.isEnabled = true
        case .recording:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "KoeType 録音中")
            button.contentTintColor = .systemRed
            toggleItem.title = "録音を停止して入力"
            toggleItem.isEnabled = true
        case .processing:
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "KoeType 処理中")
            button.contentTintColor = nil
            toggleItem.title = "処理中…"
            toggleItem.isEnabled = false
        }
    }

    @objc private func toggleAction() {
        onToggle()
    }

    @objc private func settingsAction() {
        onOpenSettings()
    }
}
