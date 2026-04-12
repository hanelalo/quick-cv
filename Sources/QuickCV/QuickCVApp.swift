import SwiftUI
import AppKit
import KeyboardShortcuts
import ServiceManagement

@main
struct QuickCVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("launchAtLogin") private var launchAtLogin = false

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

                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        appDelegate.updateLoginItem(enabled: launchAtLogin)
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
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        WindowManager.shared.setup(manager: ClipboardManager.shared)
        setupMenuBarIcon()
        
        // 读取设置并配置开机启动
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        updateLoginItem(enabled: launchAtLogin)
    }
    
    func updateLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            let launcherAppId = "com.hanelalo.QuickCV"
            SMLoginItemSetEnabled(launcherAppId as CFString, enabled)
        }
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

            let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: "")
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
        NSApp.activate(ignoringOtherApps: true)
        
        if settingsWindow == nil {
            // 创建设置窗口
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "QuickCV 设置"
            window.center()
            
            // 创建设置视图
            let settingsView = SettingsView()
            window.contentView = NSHostingView(rootView: settingsView)
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
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

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("快捷键设置")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text("唤出历史面板:")
                KeyboardShortcuts.Recorder(for: .togglePanel)
            }

            Divider()

            Toggle("开机自动启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if #available(macOS 13.0, *) {
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                        }
                    } else {
                        SMLoginItemSetEnabled("com.hanelalo.QuickCV" as CFString, newValue)
                    }
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
