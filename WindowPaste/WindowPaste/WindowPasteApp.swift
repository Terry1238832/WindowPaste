import AppKit
import SwiftUI

@main
struct WindowPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isBusy ? "camera.fill" : "camera.viewfinder")
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("窗贴")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppState.shared.start()
        AppState.shared.refreshPermissions()
        SettingsWindowController.shared.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView().environmentObject(AppState.shared)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "窗贴"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 480, height: 740))
            window.minSize = NSSize(width: 440, height: 560)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.collectionBehavior = [.moveToActiveSpace]
            window.isRestorable = true
            window.center()
            self.window = window
        }
        AppState.shared.refreshPermissions()
        Task { await AppState.shared.refreshWindows() }
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
