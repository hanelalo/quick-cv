import Foundation
import AppKit

// MARK: - Data Model

enum RichTextFormat {
    case rtf
    case html
}

enum ClipboardContentType {
    case text(String)
    case image(NSImage)
    case file(URL)
    case richText(attributedString: NSAttributedString, plainText: String, sourceFormat: RichTextFormat)

    var displayText: String? {
        switch self {
        case .text(let string): return string
        case .richText(_, let plainText, _): return plainText
        case .file(let url): return url.lastPathComponent
        case .image: return nil
        }
    }

    var searchableText: String? {
        switch self {
        case .text(let string): return string
        case .richText(_, let plainText, _): return plainText
        case .file(let url): return url.lastPathComponent + " " + url.path
        case .image: return nil
        }
    }

    var isImage: Bool {
        if case .image = self { return true }
        return false
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: ClipboardContentType
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

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Unknown App"
        let appIcon = frontApp?.icon ?? NSWorkspace.shared.icon(forFile: "/Applications/")

        // Priority: file → rich text → image → plain text
        if let detected = detectFileReference() {
            DispatchQueue.main.async {
                self.add(content: detected, sourceAppName: appName, sourceAppIcon: appIcon)
            }
        } else if let detected = detectRichText() {
            DispatchQueue.main.async {
                self.add(content: detected, sourceAppName: appName, sourceAppIcon: appIcon)
            }
        } else if let detected = detectImage() {
            DispatchQueue.main.async {
                self.add(content: detected, sourceAppName: appName, sourceAppIcon: appIcon)
            }
        } else if let detected = detectPlainText() {
            DispatchQueue.main.async {
                self.add(content: detected, sourceAppName: appName, sourceAppIcon: appIcon)
            }
        }
    }

    // MARK: - Detection Helpers

    private func detectFileReference() -> ClipboardContentType? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else { return nil }
        guard let fileURL = urls.first(where: { $0.isFileURL }) else { return nil }
        return .file(fileURL)
    }

    private func detectRichText() -> ClipboardContentType? {
        // Try RTF first, then HTML
        if let rtfData = pasteboard.data(forType: .rtf),
           let attrString = try? NSAttributedString(data: rtfData, options: [
               .documentType: NSAttributedString.DocumentType.rtf
           ], documentAttributes: nil),
           !attrString.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .richText(attributedString: attrString, plainText: attrString.string, sourceFormat: .rtf)
        }
        if let htmlData = pasteboard.data(forType: .html),
           let attrString = try? NSAttributedString(data: htmlData, options: [
               .documentType: NSAttributedString.DocumentType.html
           ], documentAttributes: nil),
           !attrString.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .richText(attributedString: attrString, plainText: attrString.string, sourceFormat: .html)
        }
        return nil
    }

    private func detectImage() -> ClipboardContentType? {
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        guard image.isValid else { return nil }
        return .image(image)
    }

    private func detectPlainText() -> ClipboardContentType? {
        guard let string = pasteboard.string(forType: .string) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return .text(string)
    }

    func add(content: ClipboardContentType, sourceAppName: String, sourceAppIcon: NSImage) {
        // Dedup logic varies by type
        var removeIndex: Int?
        switch content {
        case .text(let string):
            removeIndex = history.firstIndex(where: {
                if case .text(let existing) = $0.content { return existing == string }
                return false
            })
        case .file(let url):
            removeIndex = history.firstIndex(where: {
                if case .file(let existing) = $0.content { return existing.absoluteString == url.absoluteString }
                return false
            })
        case .richText(_, let plainText, _):
            removeIndex = history.firstIndex(where: {
                if case .richText(_, let existing, _) = $0.content { return existing == plainText }
                return false
            })
        case .image:
            break // No dedup for images
        }

        if let index = removeIndex {
            history.remove(at: index)
        }

        let item = ClipboardItem(
            content: content,
            sourceAppName: sourceAppName,
            sourceAppIcon: sourceAppIcon,
            timestamp: Date()
        )
        history.insert(item, at: 0)

        // Unified 50-item limit across all types
        if history.count > 50 {
            history.removeLast()
        }

        selectedIndex = 0
    }

    func copyToClipboard(item: ClipboardItem) {
        isInternalCopy = true
        pasteboard.clearContents()

        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)

        case .richText(let attrString, _, let format):
            // Dual-write: rich format + plain text for compatibility
            switch format {
            case .rtf:
                let rtfData = try? attrString.data(
                    from: NSRange(location: 0, length: attrString.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
                )
                if let rtfData { pasteboard.setData(rtfData, forType: .rtf) }
            case .html:
                let htmlData = try? attrString.data(
                    from: NSRange(location: 0, length: attrString.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
                )
                if let htmlData { pasteboard.setData(htmlData, forType: .html) }
            }
            pasteboard.setString(attrString.string, forType: .string)

        case .image(let image):
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                pasteboard.setData(pngData, forType: .png)
            }

        case .file(let url):
            pasteboard.writeObjects([url as NSURL])
        }

        self.lastChangeCount = pasteboard.changeCount
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
