import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                howTo
                targetPicker
                permissions
                extras
            }
            .padding(22)
        }
        .frame(minWidth: 460, minHeight: 620)
        .onAppear {
            appState.refreshPermissions()
            appState.refreshLaunchAtLogin()
            Task { await appState.refreshWindows() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.refreshPermissions()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 48, height: 48)
                .background(Color.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("窗贴")
                    .font(.title2.weight(.semibold))
                Text("按下 ⌘`，截取目标窗口并粘贴到当前光标处")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
        }
    }

    private var howTo: some View {
        GroupBox("怎么用") {
            VStack(alignment: .leading, spacing: 8) {
                labeled("1", "打开 LetsView（或你选择的软件），保持要截的窗口不要最小化")
                labeled("2", "如果有多个窗口，在下面点选要截取的那个")
                labeled("3", "把光标放到聊天框、文档等要插入图片的位置，按下 ⌘`")
                Text("软件运行时会占用系统自带的「切换当前应用窗口」快捷键。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var targetPicker: some View {
        GroupBox("截取哪个窗口") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("目标应用", selection: targetBinding) {
                    ForEach(appState.runningApps()) { app in
                        Text(app.name).tag(app)
                    }
                }
                .labelsHidden()

                HStack {
                    Text("窗口")
                        .font(.headline)
                    Spacer()
                    if appState.isRefreshingWindows {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("刷新") {
                        Task { await appState.refreshWindows() }
                    }
                    .disabled(appState.isRefreshingWindows)
                }

                windowChoiceRow(
                    id: 0,
                    title: "自动选择最大窗口",
                    subtitle: "适合只有一个窗口的软件",
                    preview: nil,
                    selected: appState.selectedWindowID == 0
                )

                if appState.availableWindows.isEmpty {
                    Text(appState.hasScreenRecording
                         ? "没有找到 \(appState.targetApp.name) 的窗口。请确认软件已打开，再点刷新。"
                         : "需要屏幕录制权限后，才能列出各个窗口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(appState.availableWindows) { window in
                        windowChoiceRow(
                            id: window.windowID,
                            title: window.displayName,
                            subtitle: nil,
                            preview: appState.windowPreviews[window.windowID],
                            selected: appState.selectedWindowID == window.windowID
                        )
                    }
                }

                if appState.selectedWindowID != 0,
                   !appState.availableWindows.contains(where: { $0.windowID == appState.selectedWindowID }) {
                    Text("已记住「\(appState.windowMenuLabel)」，但当前没找到这个窗口。打开它后再刷新一次。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button("立即试一次") {
                    appState.captureAndPaste()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var permissions: some View {
        GroupBox("权限") {
            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "屏幕录制",
                    detail: "用来列出并截取 LetsView 等窗口，不会把窗贴自己带到前台",
                    granted: appState.hasScreenRecording,
                    actionTitle: appState.hasScreenRecording ? "已开启" : "去开启"
                ) {
                    PermissionService.requestScreenRecording()
                    PermissionService.openScreenRecordingSettings()
                }

                permissionRow(
                    title: "辅助功能",
                    detail: "用来把截图自动粘贴到当前光标位置。没有此权限时仍会复制到剪贴板",
                    granted: appState.hasAccessibility,
                    actionTitle: appState.hasAccessibility ? "已开启" : "去开启"
                ) {
                    PermissionService.requestAccessibility()
                    PermissionService.openAccessibilitySettings()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var extras: some View {
        GroupBox("粘贴后") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("自动回车", isOn: autoReturnBinding)
                    .padding(.vertical, 2)
                Text("粘贴截图后再按一次回车，适合微信等聊天框直接发出去。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("登录 Mac 时自动打开窗贴", isOn: launchAtLoginBinding)
                    .padding(.vertical, 2)
                Text("开机启动更稳妥的方式是把窗贴放到「应用程序」文件夹后再勾选。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetBinding: Binding<TargetApp> {
        Binding(
            get: { appState.targetApp },
            set: { appState.setTarget($0) }
        )
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

    private func windowChoiceRow(
        id: UInt32,
        title: String,
        subtitle: String?,
        preview: NSImage?,
        selected: Bool
    ) -> some View {
        Button {
            appState.setSelectedWindow(id: id)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                previewView(preview, placeholder: id == 0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.teal : Color.secondary)
                    .font(.title3)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.teal.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.teal.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func previewView(_ image: NSImage?, placeholder: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            if placeholder {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundStyle(.secondary)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 88, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func labeled(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(.teal)
                .frame(width: 18, height: 18)
                .background(Color.teal.opacity(0.15), in: Circle())
            Text(text)
                .font(.callout)
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
                .disabled(granted)
        }
    }
}
