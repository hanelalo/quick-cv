# Extended Clipboard Content Types Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend QuickCV to support file references and rich text (RTF/HTML) in addition to plain text, with unified history limit and type-aware search.

**Architecture:** Replace the plain-text `content: String` field on `ClipboardItem` with a `ClipboardContentType` enum (text, image, file, richText). `ClipboardManager` detects type by priority (file → rich text → image → text), stores accordingly, and writes back the correct UTI on paste. `ContentView` renders each type differently in the shared `ClipItemView`. `WindowManager.paste` signature changes from `String` to `ClipboardItem`.

**Tech Stack:** SwiftUI, AppKit (NSPasteboard, NSAttributedString, NSImage, NSWorkspace), Swift Package Manager

---

## File Map

| File | Responsibility |
|------|---------------|
| `Sources/QuickCV/ClipboardManager.swift` | Data model (`ClipboardContentType`, `ClipboardItem`), clipboard polling/detection, history management, copy-to-clipboard |
| `Sources/QuickCV/ContentView.swift` | UI rendering per content type, search filtering |
| `Sources/QuickCV/WindowManager.swift` | Panel management, keyboard events, paste dispatch |

---

### Task 1: Data Model — ClipboardContentType enum and ClipboardItem update

**Files:**
- Modify: `Sources/QuickCV/ClipboardManager.swift:1-10`

- [ ] **Step 1: Replace data model in ClipboardManager.swift**

Replace lines 1-10 (the `ClipboardItem` struct) with the new enum and updated struct:

```swift
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
```

- [ ] **Step 2: Build to verify compilation errors**

Run: `swift build 2>&1 | head -30`
Expected: Multiple errors in `ClipboardManager`, `ContentView`, and `WindowManager` referencing `.content` as `String`. This confirms the enum is in place. Fix these in subsequent tasks.

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickCV/ClipboardManager.swift
git commit -m "refactor: add ClipboardContentType enum with text, image, file, richText cases"
```

---

### Task 2: ClipboardManager — detection priority and add method

**Files:**
- Modify: `Sources/QuickCV/ClipboardManager.swift:36-84` (checkForChanges and add methods)

- [ ] **Step 1: Rewrite checkForChanges() with type detection priority**

Replace the `checkForChanges()` method (lines 36-58) with:

```swift
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Skip changes caused by our own copyToClipboard
        guard !isInternalCopy else {
            isInternalCopy = false
            return
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "未知应用"
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
```

- [ ] **Step 2: Add the four detection helper methods**

Add these methods right after `checkForChanges()`:

```swift
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
```

- [ ] **Step 3: Rewrite add(content:) to accept ClipboardContentType**

Replace the existing `add(content:sourceAppName:sourceAppIcon:)` method (lines 60-84) with:

```swift
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
```

- [ ] **Step 4: Rewrite copyToClipboard to accept ClipboardItem**

Replace the existing `copyToClipboard(item:)` method (lines 86-98) with:

```swift
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
```

- [ ] **Step 5: Build to verify**

Run: `swift build 2>&1 | head -20`
Expected: Errors in `ContentView.swift` and `WindowManager.swift` only (they still reference `.content` as `String` and `paste(item: String)`).

- [ ] **Step 6: Commit**

```bash
git add Sources/QuickCV/ClipboardManager.swift
git commit -m "feat: add multi-type clipboard detection (file, rich text, image, plain text)"
```

---

### Task 3: WindowManager — update paste signature and callers

**Files:**
- Modify: `Sources/QuickCV/WindowManager.swift:51,96-97`

- [ ] **Step 1: Update paste(item:) to accept ClipboardItem**

Replace lines 96-97 (the `paste` method):

```swift
    func paste(item: ClipboardItem) {
        ClipboardManager.shared.copyToClipboard(item: item)
```

Leave the rest of the method body unchanged (the sound, hidePanel, CGEvent logic stays the same).

- [ ] **Step 2: Update keyboard event handler to pass ClipboardItem**

Replace line 51:

```swift
                    WindowManager.shared.paste(item: item.content)
```

with:

```swift
                    WindowManager.shared.paste(item: item)
```

The variable `item` is already a `ClipboardItem?` from `confirmSelection()`.

- [ ] **Step 3: Build to verify**

Run: `swift build 2>&1 | head -20`
Expected: Errors only in `ContentView.swift` (two call sites passing `item.content` as String).

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickCV/WindowManager.swift
git commit -m "refactor: change paste() signature from String to ClipboardItem"
```

---

### Task 4: ContentView — search filtering for all content types

**Files:**
- Modify: `Sources/QuickCV/ContentView.swift:52-58` (filteredHistory computed property)

- [ ] **Step 1: Rewrite filteredHistory**

Replace the `filteredHistory` computed property (lines 52-58):

```swift
    private var filteredHistory: [(Int, ClipboardItem)] {
        let enumerated = Array(manager.history.enumerated())
        if searchText.isEmpty {
            return enumerated
        }
        return enumerated.filter { _, item in
            guard let text = item.content.searchableText else { return false }
            return text.localizedCaseInsensitiveContains(searchText)
        }
    }
```

This uses the `searchableText` computed property: text/rich text match by content, file by filename+path, images are hidden (return `nil` → filtered out).

- [ ] **Step 2: Update clipItemRow paste call**

Replace line 260:

```swift
            WindowManager.shared.paste(item: item.content)
```

with:

```swift
            WindowManager.shared.paste(item: item)
```

- [ ] **Step 3: Update SearchBarWrapper Coordinator paste call**

Replace line 479:

```swift
                    WindowManager.shared.paste(item: item.content)
```

with:

```swift
                    WindowManager.shared.paste(item: item)
```

- [ ] **Step 4: Build to verify**

Run: `swift build 2>&1 | head -20`
Expected: Errors only in `ClipItemView` body (references `item.content` as String for display and metadata).

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickCV/ContentView.swift
git commit -m "feat: update search filtering to support file, rich text, and image types"
```

---

### Task 5: ContentView — ClipItemView rendering for all content types

**Files:**
- Modify: `Sources/QuickCV/ContentView.swift:306-401` (ClipItemView)

- [ ] **Step 1: Replace ClipItemView body with type-aware rendering**

Replace the `ClipItemView` struct (lines 306-401) with:

```swift
struct ClipItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let index: Int
    let onHover: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                appIconView

                VStack(alignment: .leading, spacing: 5) {
                    contentDisplay
                    metadataLine
                }

                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.white.opacity(0.15))
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Tokens.radiusItem, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusItem, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Content Display

    @ViewBuilder
    private var contentDisplay: some View {
        switch item.content {
        case .text(let string):
            Text(string)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(isSelected ? .white : Tokens.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .richText(_, let plainText, _):
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Tokens.accent1 : Tokens.textTertiary)
                Text(plainText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : Tokens.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .file(let url):
            HStack(spacing: 8) {
                fileIcon(for: url)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : Tokens.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - Metadata Line

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 8) {
            Text(item.sourceAppName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Tokens.accent1 : Tokens.textTertiary)

            Circle()
                .fill(isSelected ? Tokens.accent1.opacity(0.4) : Tokens.textMuted)
                .frame(width: 3, height: 3)

            typeMetadata
        }
        .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Tokens.textTertiary)
    }

    @ViewBuilder
    private var typeMetadata: some View {
        switch item.content {
        case .text(let string):
            Text("\(string.count) 字符")
                .font(.system(size: 10, weight: .medium, design: .rounded))

        case .richText(_, let plainText, _):
            Text("富文本 · \(plainText.count) 字符")
                .font(.system(size: 10, weight: .medium, design: .rounded))

        case .file(let url):
            Text("文件 · \(url.path)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.head)

        case .image(let image):
            Text("图片 · \(Int(image.size.width))x\(Int(image.size.height))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
    }

    // MARK: - Helpers

    private func fileIcon(for url: URL) -> some View {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
    }

    private var appIconView: some View {
        Image(nsImage: item.sourceAppIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: "7C3AED")
        } else if isHovered {
            return Tokens.bgTertiary.opacity(0.5)
        } else {
            return .clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color(hex: "6D28D9")
        } else if isHovered {
            return Tokens.border
        } else {
            return Color.clear.opacity(0)
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build 2>&1`
Expected: Build complete! (no errors)

- [ ] **Step 3: Commit**

```bash
git add Sources/QuickCV/ContentView.swift
git commit -m "feat: type-aware UI rendering for text, rich text, file, and image items"
```

---

### Task 6: Manual verification and final cleanup

**No files to create/modify — this is a testing checklist.**

- [ ] **Step 1: Build and run the app**

Run: `swift build && open .build/debug/QuickCV.app` (or use Xcode if project is open there)

- [ ] **Step 2: Verify plain text still works**
1. Copy some text from any app
2. Open QuickCV panel (Cmd+Shift+V)
3. Verify text appears in list with correct metadata ("N 字符")
4. Select and press Enter → text should paste into target app

- [ ] **Step 3: Verify file references**
1. In Finder, copy a file (Cmd+C on a file)
2. Open QuickCV panel
3. Verify file appears with file icon + filename + path in metadata
4. Select and press Enter → file should paste (copy) into target Finder window

- [ ] **Step 4: Verify rich text**
1. Copy rich text from a web browser or TextEdit (with formatting)
2. Open QuickCV panel
3. Verify item shows plain text preview with "富文本" label
4. Select and press Enter → formatted text should paste (preserving bold, links, etc.)

- [ ] **Step 5: Verify images**
1. Take a screenshot (Cmd+Shift+4)
2. Open QuickCV panel
3. Verify thumbnail appears with "图片 · WxH" metadata
4. Select and press Enter → image should paste

- [ ] **Step 6: Verify search**
1. Copy text, a file, and rich text
2. Open QuickCV panel, press Cmd+K to search
3. Type part of the text → only text and rich text items matching should appear
4. Type part of a filename → file items matching should appear
5. Images should be hidden during any search

- [ ] **Step 7: Verify history limit**
1. Copy more than 50 items total (mix of types)
2. Verify oldest items are removed to keep at 50

- [ ] **Step 8: Commit any fixes if needed**

```bash
git add -A
git commit -m "fix: address issues found during manual verification"
```
