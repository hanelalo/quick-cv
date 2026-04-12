import SwiftUI
import AppKit
import KeyboardShortcuts

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    var panel: FloatingPanel?
    private var eventMonitor: Any?
    static var onToggleSearch: (() -> Void)?
    static var isSearchActive: Bool = false

    func setup(manager: ClipboardManager) {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear
        
        let view = ContentView(manager: manager)
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self
        
        self.panel = panel

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else {
                return event
            }
            switch event.keyCode {
            case 125: // Down arrow
                ClipboardManager.shared.moveSelectionDown()
                return nil
            case 126: // Up arrow
                ClipboardManager.shared.moveSelectionUp()
                return nil
            case 36, 76: // Return or Enter
                if let item = ClipboardManager.shared.confirmSelection() {
                    WindowManager.shared.paste(item: item.content)
                }
                return nil
            case 53: // Escape
                if WindowManager.isSearchActive {
                    WindowManager.onToggleSearch?()
                } else {
                    WindowManager.shared.hidePanel()
                }
                return nil
            default:
                if event.modifierFlags.contains(.command) && event.keyCode == 40 { // Cmd+K
                    WindowManager.onToggleSearch?()
                    return nil
                }
                return event
            }
        }

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }
    }

    func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible {
            hidePanel()
        } else {
            if !ClipboardManager.shared.history.isEmpty && ClipboardManager.shared.selectedIndex == nil {
                ClipboardManager.shared.selectedIndex = 0
            }

            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func hidePanel() {
        panel?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
    }
    
    func paste(item: String) {
        ClipboardManager.shared.copyToClipboard(item: item)
        NSSound(named: "Tink")?.play()
        hidePanel()
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if accessEnabled {
            let source = CGEventSource(stateID: .hidSystemState)
            let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            cmdVDown?.flags = .maskCommand
            cmdVUp?.flags = .maskCommand
            
            // Wait slightly for our window to disappear and the target app to regain focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cmdVDown?.post(tap: .cghidEventTap)
                cmdVUp?.post(tap: .cghidEventTap)
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}
