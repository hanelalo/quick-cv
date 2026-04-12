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
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack {
                    Text("Show History Panel:")
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }

                Divider()

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _ in
                        appDelegate.updateLoginItem(enabled: launchAtLogin)
                    }

                Divider()

                Text("Auto-Paste Notice")
                    .font(.headline)
                Text("QuickCV can automatically paste content after you select it from history.\nTo enable this feature, the system may prompt you to grant Accessibility permissions.\nIf you don't see a prompt but auto-paste doesn't work, please go to:\nSystem Settings -> Privacy & Security -> Accessibility and allow QuickCV.")
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
            menu.addItem(NSMenuItem(title: "Show History Panel", action: #selector(togglePanel), keyEquivalent: "V"))
            menu.items.last?.keyEquivalentModifierMask = [.command, .shift]

            menu.addItem(.separator())

            let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
            menu.addItem(settingsItem)
            menu.addItem(.separator())

            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

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
            window.title = "QuickCV Settings"
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
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text("Show History Panel:")
                KeyboardShortcuts.Recorder(for: .togglePanel)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
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

            Text("Auto-Paste Notice")
                .font(.headline)
            Text("QuickCV can automatically paste content after you select it from history.\nTo enable this feature, the system may prompt you to grant Accessibility permissions.\nIf you don't see a prompt but auto-paste doesn't work, please go to:\nSystem Settings -> Privacy & Security -> Accessibility and allow QuickCV.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 450)
    }
}
