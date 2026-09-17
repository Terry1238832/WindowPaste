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
            window.hidesOnDeactivate = false
            window.delegate = self
            window.collectionBehavior = [.managed, .moveToActiveSpace, .fullScreenNone]
            window.isRestorable = true
            window.animationBehavior = .documentWindow
            window.tabbingMode = .disallowed
            window.center()
            self.window = window
        }
        AppState.shared.refreshPermissions()
        Task { await AppState.shared.refreshWindows() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        } else {
            window?.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.setActivationPolicy(.regular)
        return true
    }

    func windowWillMiniaturize(_ notification: Notification) {
        AppState.shared.cancelHotKeyRecording()
        NSApp.setActivationPolicy(.regular)
    }

    func windowWillClose(_ notification: Notification) {
        AppState.shared.cancelHotKeyRecording()
        NSApp.setActivationPolicy(.regular)
    }

    func windowDidResignKey(_ notification: Notification) {
        AppState.shared.cancelHotKeyRecording()
    }
}
