import Foundation
import AppKit

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: String
    let sourceAppName: String
    let sourceAppIcon: NSImage
    let timestamp: Date
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var history: [ClipboardItem] = []
    @Published var selectedIndex: Int? = nil

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private var isInternalCopy = false

    private init() {
        self.lastChangeCount = pasteboard.changeCount
        startPolling()
    }

    private func startPolling() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Skip changes caused by our own copyToClipboard
        guard !isInternalCopy else {
            isInternalCopy = false
            return
        }

        if let copiedString = pasteboard.string(forType: .string) {
            let trimmed = copiedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let frontApp = NSWorkspace.shared.frontmostApplication
                let appName = frontApp?.localizedName ?? "未知应用"
                let appIcon = frontApp?.icon ?? NSWorkspace.shared.icon(forFile: "/Applications/")

                DispatchQueue.main.async {
                    self.add(content: copiedString, sourceAppName: appName, sourceAppIcon: appIcon)
                }
            }
        }
    }

    func add(content: String, sourceAppName: String, sourceAppIcon: NSImage) {
        // Remove duplicate by content
        if let index = history.firstIndex(where: { $0.content == content }) {
            history.remove(at: index)
        }
        let item = ClipboardItem(
            content: content,
            sourceAppName: sourceAppName,
            sourceAppIcon: sourceAppIcon,
            timestamp: Date()
        )
        history.insert(item, at: 0)

        // Keep only last 50 items
        if history.count > 50 {
            history.removeLast()
        }

        // Reset selection to top
        if !history.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = nil
        }
    }

    func copyToClipboard(item: String) {
        isInternalCopy = true
        pasteboard.clearContents()
        pasteboard.setString(item, forType: .string)
        self.lastChangeCount = pasteboard.changeCount

        // Move to top of history if it already exists
        if let index = history.firstIndex(where: { $0.content == item }) {
            let existing = history.remove(at: index)
            history.insert(existing, at: 0)
            selectedIndex = 0
        }
    }

    func clear() {
        history.removeAll()
        selectedIndex = nil
    }

    func moveSelectionUp() {
        guard !history.isEmpty else { return }
        if let current = selectedIndex {
            if current > 0 {
                selectedIndex = current - 1
            }
        } else {
            selectedIndex = history.count - 1
        }
    }

    func moveSelectionDown() {
        guard !history.isEmpty else { return }
        if let current = selectedIndex {
            if current < history.count - 1 {
                selectedIndex = current + 1
            }
        } else {
            selectedIndex = 0
        }
    }

    func confirmSelection() -> ClipboardItem? {
        guard let current = selectedIndex, current < history.count else { return nil }
        return history[current]
    }
}
