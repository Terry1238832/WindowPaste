import AppKit
import Carbon
import Foundation

struct HotKey: Equatable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotKey(
        keyCode: UInt32(kVK_ANSI_Grave),
        carbonModifiers: UInt32(cmdKey)
    )

    static let modifierMask = UInt32(cmdKey | shiftKey | optionKey | controlKey)

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers & Self.modifierMask
    }

    init?(event: NSEvent) {
        if event.isARepeat { return nil }
        let code = UInt32(event.keyCode)
        if Self.isModifierKeyCode(code) { return nil }
        var modifiers: UInt32 = 0
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        self.init(keyCode: code, carbonModifiers: modifiers)
    }

    var displayName: String {
        var text = ""
        if carbonModifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        text += Self.keyName(keyCode)
        return text
    }

    var isDefault: Bool { self == .default }

    func problem() -> HotKeyRegisterResult? {
        if !hasStrongModifier && !Self.isFunctionKey(keyCode) {
            return .invalid("请加上 Command、Control 或 Option，再按一个键")
        }
        if let message = Self.reservedMessage(for: self) {
            return .conflict(message)
        }
        if !isDefault, Self.systemHotKeys().contains(self) {
            return .conflict("已与系统快捷键冲突，请换一个")
        }
        return nil
    }

    private var hasStrongModifier: Bool {
        carbonModifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    static func normalized(_ modifiers: UInt32) -> UInt32 {
        let carbon = modifiers & modifierMask
        if carbon != 0 { return carbon }

        var converted: UInt32 = 0
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 { converted |= UInt32(cmdKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 { converted |= UInt32(shiftKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 { converted |= UInt32(optionKey) }
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 { converted |= UInt32(controlKey) }
        return converted
    }

    static func systemHotKeys() -> Set<HotKey> {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let unmanaged else { return [] }
        let cfArray = unmanaged.takeRetainedValue()
        var result: Set<HotKey> = []
        for item in cfArray as NSArray {
            guard let dict = item as? NSDictionary else { continue }
            let enabledValue = dict[kHISymbolicHotKeyEnabled]
            let enabled = (enabledValue as? Bool) ?? (enabledValue as? NSNumber)?.boolValue ?? true
            guard enabled else { continue }
            guard let code = (dict[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value,
                  let modifiers = (dict[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value
            else { continue }
            result.insert(HotKey(keyCode: code, carbonModifiers: normalized(modifiers)))
        }
        return result
    }

    private static func reservedMessage(for hotKey: HotKey) -> String? {
        let mods = hotKey.carbonModifiers
        let code = Int(hotKey.keyCode)
        let cmd = UInt32(cmdKey)
        let shift = UInt32(shiftKey)
        let option = UInt32(optionKey)
        let control = UInt32(controlKey)

        switch (code, mods) {
        case (kVK_Tab, cmd), (kVK_Tab, cmd | shift):
            return "已与系统「切换应用」冲突"
        case (kVK_Space, cmd):
            return "已与 Spotlight 冲突"
        case (kVK_Space, cmd | shift):
            return "已与系统「显示聚焦搜索窗口」冲突"
        case (kVK_Escape, cmd | option):
            return "已与系统「强制退出」冲突"
        case (kVK_ANSI_Q, cmd | control), (kVK_ANSI_Q, control | cmd):
            return "已与系统「锁定屏幕」冲突"
        case (kVK_ANSI_3, cmd | shift), (kVK_ANSI_4, cmd | shift), (kVK_ANSI_5, cmd | shift):
            return "已与系统截图快捷键冲突"
        case (kVK_ANSI_Q, cmd):
            return "这个组合会退出应用，请换一个"
        case (kVK_ANSI_W, cmd):
            return "这个组合会关闭窗口，请换一个"
        case (kVK_ANSI_H, cmd):
            return "这个组合会隐藏窗口，请换一个"
        case (kVK_ANSI_M, cmd):
            return "这个组合会最小化窗口，请换一个"
        case (kVK_ANSI_Comma, cmd):
            return "这个组合常用于打开设置，请换一个"
        case (kVK_ANSI_C, cmd), (kVK_ANSI_V, cmd), (kVK_ANSI_X, cmd), (kVK_ANSI_A, cmd):
            return "这个组合是常用编辑快捷键，请换一个"
        case (kVK_ANSI_Z, cmd), (kVK_ANSI_Z, cmd | shift):
            return "这个组合是撤销 / 重做，请换一个"
        case (kVK_ANSI_S, cmd), (kVK_ANSI_N, cmd), (kVK_ANSI_O, cmd), (kVK_ANSI_P, cmd):
            return "这个组合是常用系统快捷键，请换一个"
        default:
            return nil
        }
    }

    private static func isModifierKeyCode(_ code: UInt32) -> Bool {
        switch Int(code) {
        case kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
             kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
             kVK_CapsLock, kVK_Function:
            return true
        default:
            return false
        }
    }

    private static func isFunctionKey(_ code: UInt32) -> Bool {
        switch Int(code) {
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
             kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
             kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            return true
        default:
            return false
        }
    }

    static func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_Grave: return "·"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_Space: return "空格"
        case kVK_Return: return "↩"
        case kVK_ANSI_KeypadEnter: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "PgUp"
        case kVK_PageDown: return "PgDn"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        case kVK_ANSI_Keypad0: return "小键盘 0"
        case kVK_ANSI_Keypad1: return "小键盘 1"
        case kVK_ANSI_Keypad2: return "小键盘 2"
        case kVK_ANSI_Keypad3: return "小键盘 3"
        case kVK_ANSI_Keypad4: return "小键盘 4"
        case kVK_ANSI_Keypad5: return "小键盘 5"
        case kVK_ANSI_Keypad6: return "小键盘 6"
        case kVK_ANSI_Keypad7: return "小键盘 7"
        case kVK_ANSI_Keypad8: return "小键盘 8"
        case kVK_ANSI_Keypad9: return "小键盘 9"
        case kVK_ANSI_KeypadDecimal: return "小键盘 ."
        case kVK_ANSI_KeypadPlus: return "小键盘 +"
        case kVK_ANSI_KeypadMinus: return "小键盘 -"
        case kVK_ANSI_KeypadMultiply: return "小键盘 *"
        case kVK_ANSI_KeypadDivide: return "小键盘 /"
        case kVK_ANSI_KeypadEquals: return "小键盘 ="
        case kVK_ANSI_KeypadClear: return "Clear"
        case kVK_Help: return "Help"
        case kVK_VolumeUp: return "音量加"
        case kVK_VolumeDown: return "音量减"
        case kVK_Mute: return "静音"
        default: return "键\(keyCode)"
        }
    }
}

enum HotKeyRegisterResult: Equatable {
    case registered
    case invalid(String)
    case conflict(String)
    case failed(String)
}
