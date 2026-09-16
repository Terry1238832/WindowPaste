import AppKit
import Carbon
import Foundation

enum ClipboardPasteService {
    static func copyImage(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        if let tiff = image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
            if let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                pasteboard.setData(png, forType: .png)
            }
        }
    }

    /// 等 Command 键松开后再发送 ⌘V，避免和触发快捷键抢按键。
    static func pasteWhenReady(pressReturn: Bool = false) async {
        for _ in 0..<40 {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.isEmpty {
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        try? await Task.sleep(nanoseconds: 40_000_000)
        postKey(kVK_ANSI_V, flags: .maskCommand)

        if pressReturn {
            try? await Task.sleep(nanoseconds: 280_000_000)
            postKey(kVK_Return, flags: [])
        }
    }

    private static func postKey(_ keyCode: Int, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let code = CGKeyCode(keyCode)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
