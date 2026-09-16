import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case permissionDenied
    case appNotRunning(String)
    case windowNotFound(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要屏幕录制权限才能截取窗口"
        case .appNotRunning(let name):
            return "没有找到 \(name)，请先打开该软件"
        case .windowNotFound(let name):
            return "没有找到 \(name) 的可用窗口，请确认窗口没有最小化"
        case .failed(let message):
            return "截图失败：\(message)"
        }
    }
}

enum WindowCaptureService {
    static func capture(
        target: TargetApp,
        preferredWindowID: UInt32? = nil,
        preferredTitle: String? = nil
    ) async throws -> NSImage {
        guard isAppRunning(target) else {
            throw CaptureError.appNotRunning(target.name)
        }

        if !PermissionService.hasScreenRecording {
            PermissionService.requestScreenRecording()
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            if content.windows.isEmpty && content.displays.isEmpty {
                throw CaptureError.permissionDenied
            }
            guard let window = pickWindow(
                from: content.windows,
                target: target,
                preferredWindowID: preferredWindowID,
                preferredTitle: preferredTitle
            ) else {
                throw CaptureError.windowNotFound(preferredTitle ?? target.name)
            }
            return try await capture(window: window)
        } catch let error as CaptureError {
            throw error
        } catch {
            if !PermissionService.hasScreenRecording {
                throw CaptureError.permissionDenied
            }
            if let image = fallbackCapture(
                target: target,
                preferredWindowID: preferredWindowID,
                preferredTitle: preferredTitle
            ) {
                return image
            }
            throw CaptureError.failed(error.localizedDescription)
        }
    }

    static func listWindows(for target: TargetApp) async throws -> [TargetWindow] {
        if !PermissionService.hasScreenRecording {
            PermissionService.requestScreenRecording()
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if content.windows.isEmpty && content.displays.isEmpty {
                throw CaptureError.permissionDenied
            }
            let windows = matchedWindows(from: content.windows, target: target)
                .filter(\.isOnScreen)
                .map(TargetWindow.init(window:))
            if !windows.isEmpty {
                return sorted(windows)
            }
        } catch let error as CaptureError {
            throw error
        } catch {
            if !PermissionService.hasScreenRecording {
                throw CaptureError.permissionDenied
            }
        }

        return sorted(listWindowsFromCG(target: target).filter(\.isOnScreen))
    }

    static func captureWindowID(_ windowID: UInt32, preview: Bool = false) async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            if let image = fallbackCapture(windowID: CGWindowID(windowID)) {
                return image
            }
            throw CaptureError.windowNotFound("指定窗口")
        }
        return try await capture(window: window, preview: preview)
    }

    private static func isAppRunning(_ target: TargetApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains { target.matches(runningApp: $0) }
    }

    private static func matchedWindows(from windows: [SCWindow], target: TargetApp) -> [SCWindow] {
        windows.filter { window in
            guard window.frame.width >= 60, window.frame.height >= 60 else { return false }
            if window.windowLayer != 0 { return false }
            return target.matches(
                applicationName: window.owningApplication?.applicationName,
                bundleIdentifier: window.owningApplication?.bundleIdentifier
            )
        }
    }

    private static func pickWindow(
        from windows: [SCWindow],
        target: TargetApp,
        preferredWindowID: UInt32?,
        preferredTitle: String?
    ) -> SCWindow? {
        let matched = matchedWindows(from: windows, target: target)
        if let preferredWindowID, preferredWindowID != 0,
           let exact = matched.first(where: { $0.windowID == preferredWindowID }) {
            return exact
        }

        let wantedTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !wantedTitle.isEmpty {
            let titled = matched.filter { ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == wantedTitle }
            if titled.count == 1 {
                return titled[0]
            }
            if let onScreen = titled.first(where: \.isOnScreen) {
                return onScreen
            }
            if let first = titled.first {
                return first
            }
        }

        return largest(in: matched)
    }

    private static func largest(in windows: [SCWindow]) -> SCWindow? {
        let onScreen = windows.filter(\.isOnScreen)
        let pool = onScreen.isEmpty ? windows : onScreen
        return pool.max { lhs, rhs in
            (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
        }
    }

    private static func capture(window: SCWindow, preview: Bool = false) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = max(CGFloat(filter.pointPixelScale), NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        let width = max(window.frame.width, filter.contentRect.width)
        let height = max(window.frame.height, filter.contentRect.height)
        var pixelWidth = max(Int((width * scale).rounded()), 1)
        var pixelHeight = max(Int((height * scale).rounded()), 1)
        if preview {
            let maxEdge = 360
            let longest = max(pixelWidth, pixelHeight)
            if longest > maxEdge {
                let ratio = CGFloat(maxEdge) / CGFloat(longest)
                pixelWidth = max(Int((CGFloat(pixelWidth) * ratio).rounded()), 1)
                pixelHeight = max(Int((CGFloat(pixelHeight) * ratio).rounded()), 1)
            }
        }
        config.width = pixelWidth
        config.height = pixelHeight
        config.showsCursor = false
        config.colorSpaceName = CGColorSpace.sRGB
        config.shouldBeOpaque = true
        if #available(macOS 14.2, *) {
            config.captureResolution = preview ? .automatic : .best
            config.ignoreShadowsSingleWindow = true
        }

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private static func fallbackCapture(
        target: TargetApp,
        preferredWindowID: UInt32?,
        preferredTitle: String?
    ) -> NSImage? {
        let windowID = cgWindowID(
            for: target,
            preferredWindowID: preferredWindowID,
            preferredTitle: preferredTitle
        )
        guard let windowID else { return nil }
        return fallbackCapture(windowID: windowID)
    }

    private static func fallbackCapture(windowID: CGWindowID) -> NSImage? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("windowpaste-\(windowID).png")
        try? FileManager.default.removeItem(at: url)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(windowID), url.path]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0, let image = NSImage(contentsOf: url) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return image
    }

    private static func listWindowsFromCG(target: TargetApp) -> [TargetWindow] {
        cgWindowInfos(for: target).map { info in
            TargetWindow(
                windowID: info.id,
                title: info.title,
                width: Int(info.width.rounded()),
                height: Int(info.height.rounded()),
                isOnScreen: info.isOnScreen
            )
        }
    }

    private static func cgWindowID(
        for target: TargetApp,
        preferredWindowID: UInt32?,
        preferredTitle: String?
    ) -> CGWindowID? {
        let infos = cgWindowInfos(for: target)
        if let preferredWindowID, preferredWindowID != 0,
           let exact = infos.first(where: { $0.id == preferredWindowID }) {
            return CGWindowID(exact.id)
        }

        let wantedTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !wantedTitle.isEmpty {
            let titled = infos.filter { $0.title == wantedTitle }
            if let match = titled.first(where: \.isOnScreen) ?? titled.first {
                return CGWindowID(match.id)
            }
        }

        let onScreen = infos.filter(\.isOnScreen)
        let pool = onScreen.isEmpty ? infos : onScreen
        return pool.max { $0.width * $0.height < $1.width * $1.height }.map { CGWindowID($0.id) }
    }

    private struct CGWindowInfo {
        let id: UInt32
        let title: String
        let width: CGFloat
        let height: CGFloat
        let isOnScreen: Bool
    }

    private static func cgWindowInfos(for target: TargetApp) -> [CGWindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var result: [CGWindowInfo] = []
        for info in list {
            let owner = info[kCGWindowOwnerName as String] as? String
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }
            guard target.matches(applicationName: owner, bundleIdentifier: nil) else { continue }
            guard let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            guard width >= 60, height >= 60 else { continue }
            let windowID = info[kCGWindowNumber as String] as? UInt32 ?? 0
            guard windowID != 0 else { continue }
            result.append(
                CGWindowInfo(
                    id: windowID,
                    title: info[kCGWindowName as String] as? String ?? "",
                    width: width,
                    height: height,
                    isOnScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? false
                )
            )
        }
        return result
    }

    private static func sorted(_ windows: [TargetWindow]) -> [TargetWindow] {
        windows.sorted { lhs, rhs in
            if lhs.isOnScreen != rhs.isOnScreen {
                return lhs.isOnScreen && !rhs.isOnScreen
            }
            return (lhs.width * lhs.height) > (rhs.width * rhs.height)
        }
    }
}

private extension TargetWindow {
    init(window: SCWindow) {
        self.init(
            windowID: window.windowID,
            title: window.title ?? "",
            width: Int(window.frame.width.rounded()),
            height: Int(window.frame.height.rounded()),
            isOnScreen: window.isOnScreen
        )
    }
}
