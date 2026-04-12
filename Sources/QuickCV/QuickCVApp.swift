import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct QuickCVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 20) {
                Text("快捷键设置")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack {
                    Text("唤出历史面板:")
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }

                Divider()

                Text("自动粘贴提示")
                    .font(.headline)
                Text("QuickCV 可以在您选择历史记录后自动帮您粘贴。\n若要开启此功能，系统可能会弹窗请求辅助功能权限。\n如果未弹窗但无法自动粘贴，请前往：\n系统设置 -> 隐私与安全性 -> 辅助功能 并允许 QuickCV。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(width: 450)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        WindowManager.shared.setup(manager: ClipboardManager.shared)
        setupMenuBarIcon()
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let logo = Bundle.main.image(forResource: "logo") {
                let size = NSSize(width: 18, height: 18)
                let resized = logo.resized(to: size)
                button.image = resized
                button.image?.isTemplate = false
            } else {
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "QuickCV")
            }

            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "显示历史面板", action: #selector(togglePanel), keyEquivalent: "V"))
            menu.items.last?.keyEquivalentModifierMask = [.command, .shift]

            menu.addItem(.separator())

            let settingsItem = NSMenuItem(title: "设置快捷键...", action: #selector(openSettings), keyEquivalent: "")
            menu.addItem(settingsItem)
            menu.addItem(.separator())

            menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

            statusItem?.menu = menu
        }
    }

    @objc private func togglePanel() {
        WindowManager.shared.togglePanel()
    }

    @objc private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: self.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        newImage.isTemplate = false
        return newImage
    }
}
