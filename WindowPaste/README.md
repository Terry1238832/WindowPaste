# 窗贴

macOS 菜单栏小工具。按下 **⌘`**（Esc 正下方的 `` ` `` 键）后，会截取 LetsView 或其他指定软件的窗口，复制到剪贴板，并粘贴到当前光标位置。

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-teal) ![Apple Silicon & Intel](https://img.shields.io/badge/arch-Universal-lightgrey)

## 安装

1. 从 [Releases](../../releases/latest) 下载 `窗贴-1.0.0.dmg`
2. 打开磁盘映像，把 **窗贴** 拖进 **应用程序**
3. 第一次打开时，如果系统提示无法验证开发者：按住 Control 点击图标 → 打开

## 使用

1. 打开 LetsView（或其他要截的软件），窗口不要最小化
2. 在设置里选择目标软件和窗口
3. 需要时打开 **自动回车**（粘贴后自动发送，适合微信等聊天框）
4. 把光标放到要插入图片的位置，按下 ⌘`

运行时会占用系统自带的「切换当前应用窗口」快捷键。关掉设置窗口不会退出，点程序坞图标即可再打开。

## 权限

- **屏幕录制**：列出并截取目标窗口
- **辅助功能**：自动粘贴，以及可选的自动回车

## 从源码编译

需要 Xcode 15+ / macOS 14+。

```bash
./release.sh
```

会生成 `dist/窗贴-1.0.0.dmg`。

## 许可证

MIT
