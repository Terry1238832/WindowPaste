import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

enum PermissionService {
    static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    static func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [prompt: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openScreenRecordingSettings() {
        openSettings([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        ])
    }

    static func openAccessibilitySettings() {
        openSettings([
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ])
    }

    private static func openSettings(_ candidates: [String]) {
        for value in candidates {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
