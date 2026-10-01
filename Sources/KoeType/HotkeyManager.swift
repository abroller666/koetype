import Carbon.HIToolbox
import Foundation

/// ⌥Space のグローバルホットキー(トグル)と、録音中のみ有効な Esc(キャンセル)を管理する。
final class HotkeyManager {
    var onToggle: (() -> Void)?
    var onCancel: (() -> Void)?

    private var toggleRef: EventHotKeyRef?
    private var escRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let signature = fourCharCode("KOET")
    private static let toggleID: UInt32 = 1
    private static let escID: UInt32 = 2

    func registerToggleHotkey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            hotkeyEventHandler,
                            1,
                            &spec,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &handlerRef)
        let id = EventHotKeyID(signature: Self.signature, id: Self.toggleID)
        RegisterEventHotKey(UInt32(kVK_Space),
                            UInt32(optionKey),
                            id,
                            GetApplicationEventTarget(),
                            0,
                            &toggleRef)
    }

    /// Esc は常時奪うとシステム全体に影響するため、録音中のみ登録する。
    func setEscEnabled(_ enabled: Bool) {
        if enabled, escRef == nil {
            let id = EventHotKeyID(signature: Self.signature, id: Self.escID)
            RegisterEventHotKey(UInt32(kVK_Escape),
                                0,
                                id,
                                GetApplicationEventTarget(),
                                0,
                                &escRef)
        } else if !enabled, let ref = escRef {
            UnregisterEventHotKey(ref)
            escRef = nil
        }
    }

    fileprivate func handle(hotkeyID: UInt32) {
        switch hotkeyID {
        case Self.toggleID: onToggle?()
        case Self.escID: onCancel?()
        default: break
        }
    }
}

private func hotkeyEventHandler(_ callRef: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotkeyID = EventHotKeyID()
    GetEventParameter(event,
                      EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID),
                      nil,
                      MemoryLayout<EventHotKeyID>.size,
                      nil,
                      &hotkeyID)
    if let userData {
        Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().handle(hotkeyID: hotkeyID.id)
    }
    return noErr
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for byte in string.utf8.prefix(4) {
        result = (result << 8) | OSType(byte)
    }
    return result
}
