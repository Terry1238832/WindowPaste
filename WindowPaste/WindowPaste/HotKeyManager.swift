import Carbon
import Foundation

/// Carbon 回调不能捕获上下文，所以用全局入口转到 AppState。
private var registeredHotKeyHandler: (() -> Void)?

private func carbonHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    registeredHotKeyHandler?()
    return noErr
}

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// ⌘` —— Esc 下方的反引号键，中文里常被写成 Command+·
    func register(_ handler: @escaping () -> Void) {
        unregister()
        registeredHotKeyHandler = {
            DispatchQueue.main.async {
                handler()
            }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCharCode("WPST")
        hotKeyID.id = 1

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Grave),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("窗贴：注册快捷键 ⌘` 失败，错误码 \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        registeredHotKeyHandler = nil
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for byte in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(byte)
    }
    return result
}
