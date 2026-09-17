import AppKit
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button("截取并粘贴（\(appState.hotKey.displayName)）") {
            appState.captureAndPaste()
        }

        Text("目标：\(appState.targetApp.name)")
        Text("窗口：\(appState.windowMenuLabel)")

        if !appState.availableWindows.isEmpty {
            Menu("选择窗口") {
                Button("自动（最大窗口）") {
                    appState.setSelectedWindow(id: 0)
                }
                Divider()
                ForEach(appState.availableWindows) { window in
                    Button(window.displayName) {
                        appState.setSelectedWindow(id: window.windowID)
                    }
                }
                Divider()
                Button("刷新窗口列表") {
                    Task { await appState.refreshWindows() }
                }
            }
        }

        Divider()

        Toggle("自动回车", isOn: autoReturnBinding)

        Button("显示设置窗口") {
            SettingsWindowController.shared.show()
        }

        Toggle("登录时打开", isOn: launchAtLoginBinding)

        Divider()

        Button("退出窗贴") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLogin },
            set: { appState.setLaunchAtLogin($0) }
        )
    }

    private var autoReturnBinding: Binding<Bool> {
        Binding(
            get: { appState.autoPressReturn },
            set: { appState.setAutoPressReturn($0) }
        )
    }
}
