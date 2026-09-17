import AppKit
import Carbon
import Combine
import Foundation
import os
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private static let nameKey = "targetAppName"
    private static let bundleKey = "targetBundleIdentifier"
    private static let windowIDKey = "targetWindowID"
    private static let windowTitleKey = "targetWindowTitle"
    private static let autoReturnKey = "autoPressReturn"
    private static let hotKeyCodeKey = "hotKeyCode"
    private static let hotKeyModifiersKey = "hotKeyModifiers"

    private let logger = Logger(subsystem: "com.liangyu.windowpaste", category: "app")

    @Published var targetApp: TargetApp
    @Published var availableWindows: [TargetWindow] = []
    @Published var windowPreviews: [UInt32: NSImage] = [:]
    @Published var selectedWindowID: UInt32
    @Published var selectedWindowTitle: String
    @Published var isRefreshingWindows = false
    @Published var isBusy = false
    @Published var hasScreenRecording = false
    @Published var hasAccessibility = false
    @Published var launchAtLogin = false
    @Published var autoPressReturn = false
    @Published var hotKey: HotKey
    @Published var isRecordingHotKey = false
    @Published var hotKeyWarning: String?
    @Published var lastMessage: String?

    private var started = false
    private var lastTriggerAt: Date = .distantPast
    private var previewTask: Task<Void, Never>?
    private var recordingMonitor: Any?

    var windowMenuLabel: String {
        if selectedWindowID == 0 {
            return "自动（最大窗口）"
        }
        if let window = availableWindows.first(where: { $0.windowID == selectedWindowID }) {
            return window.displayName
        }
        if !selectedWindowTitle.isEmpty {
            return selectedWindowTitle
        }
        return "指定窗口"
    }

    private init() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: Self.nameKey), !name.isEmpty {
            targetApp = TargetApp(
                name: name,
                bundleIdentifier: defaults.string(forKey: Self.bundleKey)
            )
        } else {
            targetApp = .letsView
        }
        selectedWindowID = UInt32(defaults.integer(forKey: Self.windowIDKey))
        selectedWindowTitle = defaults.string(forKey: Self.windowTitleKey) ?? ""
        autoPressReturn = defaults.bool(forKey: Self.autoReturnKey)
        if defaults.object(forKey: Self.hotKeyCodeKey) != nil {
            hotKey = HotKey(
                keyCode: UInt32(defaults.integer(forKey: Self.hotKeyCodeKey)),
                carbonModifiers: UInt32(defaults.integer(forKey: Self.hotKeyModifiersKey))
            )
        } else {
            hotKey = .default
        }
    }

    func start() {
        guard !started else { return }
        started = true
        ProcessInfo.processInfo.disableAutomaticTermination("listening for capture hotkey")
        HotKeyManager.shared.setHandler { [weak self] in
            self?.captureAndPaste()
        }
        if !registerCurrentHotKey(), hotKey != .default {
            hotKey = .default
            persistHotKey()
            _ = registerCurrentHotKey()
        }
        refreshPermissions()
        refreshLaunchAtLogin()
        Task { await refreshWindows() }
        logger.info("窗贴已启动，目标 \(self.targetApp.name, privacy: .public)")
    }

    func captureAndPaste() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerAt) > 0.7 else { return }
        lastTriggerAt = now
        guard !isBusy else { return }

        isBusy = true
        let target = targetApp
        let windowID = selectedWindowID
        let windowTitle = selectedWindowTitle
        let pressReturn = autoPressReturn
        Task {
            defer { isBusy = false }
            do {
                let image = try await WindowCaptureService.capture(
                    target: target,
                    preferredWindowID: windowID == 0 ? nil : windowID,
                    preferredTitle: windowTitle.isEmpty ? nil : windowTitle
                )
                ClipboardPasteService.copyImage(image)
                let label = windowID == 0 ? target.name : (windowTitle.isEmpty ? target.name : windowTitle)
                if PermissionService.hasAccessibility {
                    await ClipboardPasteService.pasteWhenReady(pressReturn: pressReturn)
                    if pressReturn {
                        present("已粘贴并发送 \(label) 截图", success: true)
                    } else {
                        present("已粘贴 \(label) 截图", success: true)
                    }
                } else {
                    PermissionService.requestAccessibility()
                    present("已复制到剪贴板。要自动粘贴，请开启辅助功能权限", success: false)
                }
                refreshPermissions()
            } catch {
                logger.error("截图失败: \(error.localizedDescription, privacy: .public)")
                present(error.localizedDescription, success: false)
                refreshPermissions()
            }
        }
    }

    func setTarget(_ app: TargetApp) {
        let changed = app != targetApp
        targetApp = app
        UserDefaults.standard.set(app.name, forKey: Self.nameKey)
        UserDefaults.standard.set(app.bundleIdentifier, forKey: Self.bundleKey)
        if changed {
            setSelectedWindow(id: 0)
            Task { await refreshWindows() }
        }
    }

    func setSelectedWindow(id: UInt32) {
        selectedWindowID = id
        if id == 0 {
            selectedWindowTitle = ""
        } else if let window = availableWindows.first(where: { $0.windowID == id }) {
            selectedWindowTitle = window.title
        }
        UserDefaults.standard.set(Int(id), forKey: Self.windowIDKey)
        UserDefaults.standard.set(selectedWindowTitle, forKey: Self.windowTitleKey)
    }

    func refreshWindows() async {
        isRefreshingWindows = true
        defer { isRefreshingWindows = false }
        do {
            let windows = try await WindowCaptureService.listWindows(for: targetApp)
            availableWindows = windows
            if selectedWindowID != 0,
               !windows.contains(where: { $0.windowID == selectedWindowID }),
               !selectedWindowTitle.isEmpty {
                if let match = windows.first(where: {
                    $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == selectedWindowTitle
                }) {
                    setSelectedWindow(id: match.windowID)
                }
            }
            await loadPreviews(for: windows)
        } catch {
            logger.error("刷新窗口列表失败: \(error.localizedDescription, privacy: .public)")
            availableWindows = []
            windowPreviews = [:]
        }
    }

    func refreshPermissions() {
        hasScreenRecording = PermissionService.hasScreenRecording
        hasAccessibility = PermissionService.hasAccessibility
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            present("开机启动设置失败：\(error.localizedDescription)", success: false)
        }
        refreshLaunchAtLogin()
    }

    func setAutoPressReturn(_ enabled: Bool) {
        autoPressReturn = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoReturnKey)
    }

    func toggleHotKeyRecording() {
        if isRecordingHotKey {
            cancelHotKeyRecording()
        } else {
            beginHotKeyRecording()
        }
    }

    func beginHotKeyRecording() {
        hotKeyWarning = nil
        isRecordingHotKey = true
        HotKeyManager.shared.suspend()
        stopRecordingMonitor()
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotKeyRecordingEvent(event)
            return nil
        }
    }

    func cancelHotKeyRecording() {
        guard isRecordingHotKey else { return }
        finishRecording(resume: true)
    }

    func restoreDefaultHotKey() {
        applyHotKey(.default)
    }

    func applyHotKey(_ newHotKey: HotKey) {
        finishRecording(resume: false)
        if newHotKey == hotKey {
            HotKeyManager.shared.resume()
            hotKeyWarning = nil
            return
        }
        switch HotKeyManager.shared.apply(newHotKey) {
        case .registered:
            hotKey = newHotKey
            persistHotKey()
            hotKeyWarning = nil
        case .invalid(let message), .conflict(let message), .failed(let message):
            hotKeyWarning = message
            HotKeyManager.shared.resume()
        }
    }

    private func handleHotKeyRecordingEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyFunction = flags.isEmpty || flags == .function || flags == .numericPad
        if event.keyCode == UInt16(kVK_Escape), onlyFunction || flags.isEmpty {
            cancelHotKeyRecording()
            return
        }
        guard let captured = HotKey(event: event) else { return }
        applyHotKey(captured)
    }

    private func finishRecording(resume: Bool) {
        isRecordingHotKey = false
        stopRecordingMonitor()
        if resume {
            HotKeyManager.shared.resume()
        }
    }

    private func stopRecordingMonitor() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
            self.recordingMonitor = nil
        }
    }

    private func persistHotKey() {
        UserDefaults.standard.set(Int(hotKey.keyCode), forKey: Self.hotKeyCodeKey)
        UserDefaults.standard.set(Int(hotKey.carbonModifiers), forKey: Self.hotKeyModifiersKey)
    }

    @discardableResult
    private func registerCurrentHotKey() -> Bool {
        switch HotKeyManager.shared.apply(hotKey) {
        case .registered:
            return true
        case .invalid(let message), .conflict(let message), .failed(let message):
            hotKeyWarning = message
            present(message, success: false)
            return false
        }
    }

    func runningApps() -> [TargetApp] {
        var apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> TargetApp? in
                guard let name = app.localizedName else { return nil }
                if app.bundleIdentifier == Bundle.main.bundleIdentifier { return nil }
                return TargetApp(name: name, bundleIdentifier: app.bundleIdentifier)
            }

        if !apps.contains(where: { $0.id == targetApp.id }) {
            apps.insert(targetApp, at: 0)
        }
        if !apps.contains(where: { $0.bundleIdentifier == TargetApp.letsView.bundleIdentifier }) {
            apps.insert(.letsView, at: 0)
        }

        var seen = Set<String>()
        return apps.filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.bundleIdentifier == TargetApp.letsView.bundleIdentifier { return true }
                if rhs.bundleIdentifier == TargetApp.letsView.bundleIdentifier { return false }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private func loadPreviews(for windows: [TargetWindow]) async {
        previewTask?.cancel()
        windowPreviews = [:]
        previewTask = Task { [weak self] in
            for window in windows.prefix(8) {
                if Task.isCancelled { return }
                if let image = try? await WindowCaptureService.captureWindowID(window.windowID, preview: true) {
                    await MainActor.run {
                        self?.windowPreviews[window.windowID] = image
                    }
                }
            }
        }
        await previewTask?.value
    }

    private func present(_ text: String, success: Bool) {
        lastMessage = text
        HUDController.shared.show(text: text, success: success)
    }
}
