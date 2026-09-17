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
    private var activeHotKey: HotKey?

    func setHandler(_ handler: @escaping () -> Void) {
        registeredHotKeyHandler = {
            DispatchQueue.main.async {
                handler()
            }
        }
        ensureEventHandler()
    }

    @discardableResult
    func apply(_ hotKey: HotKey) -> HotKeyRegisterResult {
        if let problem = hotKey.problem() {
            return problem
        }

        removeHotKeyRef()
        let status = registerRef(hotKey)
        if status == noErr {
            activeHotKey = hotKey
            return .registered
        }

        if let activeHotKey {
            _ = registerRef(activeHotKey)
        }

        if status == eventHotKeyExistsErr {
            return .conflict("这个快捷键已被其他软件占用")
        }
        return .failed("快捷键注册失败（\(status)）")
    }

    func suspend() {
        removeHotKeyRef()
    }

    func resume() {
        guard let activeHotKey else { return }
        _ = registerRef(activeHotKey)
    }

    func unregister() {
        removeHotKeyRef()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        registeredHotKeyHandler = nil
        activeHotKey = nil
    }

    private func ensureEventHandler() {
        guard eventHandlerRef == nil else { return }
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
    }

    private func registerRef(_ hotKey: HotKey) -> OSStatus {
        removeHotKeyRef()
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCharCode("WPST")
        hotKeyID.id = 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        }
        return status
    }

    private func removeHotKeyRef() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    for byte in string.utf8.prefix(4) {
        result = (result << 8) + FourCharCode(byte)
    }
    return result
}
