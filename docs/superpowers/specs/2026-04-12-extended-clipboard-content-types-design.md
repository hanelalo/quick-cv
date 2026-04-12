# Extended Clipboard Content Types Design

**Date:** 2026-04-12
**Status:** Approved
**Supersedes:** 2026-04-12-image-clipboard-support-design.md (extends it)

## Goal

Extend QuickCV clipboard support beyond text and images to include file references and rich text. Users can copy files from Finder or rich text from browsers/word processors and see them in the clipboard history panel with appropriate previews.

## Requirements

- Support file references from Finder (file URLs) via `NSPasteboard`
- Support rich text content (RTF/HTML) from browsers, word processors, etc.
- All content types (text, file, rich text, image) share a unified 50-item history limit
- Search filters across text, rich text (by plain text content), and file references (by filename + path); images hidden during search
- Content stored in memory only (lost on app restart, consistent with existing behavior)

## Data Model

### ClipboardContentType (replaces earlier two-case enum)

```swift
enum ClipboardContentType {
    case text(String)
    case image(NSImage)
    case file(URL)  // stores path only; file content is NOT loaded into memory
    case richText(attributedString: NSAttributedString, plainText: String, sourceFormat: RichTextFormat)

enum RichTextFormat {
    case rtf
    case html
}
}
```

### Computed properties on ClipboardContentType

- `displayText: String?` — text shown in list: `.text` → original string; `.richText` → plainText; `.file` → filename; `.image` → nil
- `searchableText: String?` — text for search matching: `.text` → original string; `.richText` → plainText; `.file` → filename + path; `.image` → nil

### File reference memory behavior

`.file(URL)` stores only the file path, not the file content. This means:
- Memory cost per file entry is a single URL string, regardless of file size
- Paste writes the URL back to NSPasteboard; the receiving app reads the file itself
- If the original file is moved or deleted before paste, the receiving app will fail to find it (same as macOS native behavior when pasting a file reference after the source is gone)

### ClipboardItem (unchanged structure)

```swift
struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: ClipboardContentType
    let sourceAppName: String
    let sourceAppIcon: NSImage
    let timestamp: Date
}
```

## ClipboardManager Changes

### Detection priority

`checkForChanges()` checks types in this order, capturing only the first match:

1. **File references**: `pasteboard.readObjects(forClasses: [NSURL.self])`, filtered to `isFileURL`
2. **Rich text**: `pasteboard.data(forType: .rtf)` first; if absent, fall back to `.html`. Plain text extracted via `NSAttributedString(data:options:)`
3. **Image**: `NSImage(pasteboard:)`
4. **Plain text**: `pasteboard.string(forType: .string)` (existing logic)

### Dedup

- Text: string comparison (unchanged)
- File: URL absolute path comparison
- Rich text: plainText comparison
- Image: no dedup

### History limit

- Unified 50-item limit across all types (text, file, rich text, image)
- When exceeded, remove the oldest item regardless of type

### Paste back

`copyToClipboard(item:)` writes to NSPasteboard based on type:

| Type | Written UTI types |
|------|-------------------|
| `.text` | `.string` |
| `.richText` | `.rtf` (or `.html` if originally HTML) + `.string` (dual-write for compatibility) |
| `.image` | `.png` |
| `.file` | `.fileURL` |

## UI Changes

### ClipItemView

All types use the same `ClipItemView`, branching on `item.content`:

**File references (`.file`):**
- Left: source app icon (unchanged)
- Center: file type icon (folder, document, code, etc.) + filename
- Metadata line: `sourceAppName · 文件 · /path/to/file`
- Selection/hover behavior identical to text items

**Rich text (`.richText`):**
- Left: source app icon (unchanged)
- Center: plainText preview (max 2 lines)
- Metadata line: `sourceAppName · 富文本`
- Selection/hover behavior identical to text items

**Image (`.image`):** (from original design)
- Left: source app icon
- Center: thumbnail (max height 80pt, proportional width, rounded corners)
- Metadata line: `sourceAppName · 图片 · WxH`

**Text (`.text`):**
- No changes to existing layout

### Search filtering

`filteredHistory` iterates all items:
- `.text`: match against original string
- `.richText`: match against plainText
- `.file`: match against filename + path
- `.image`: hidden when search text is non-empty

## WindowManager Changes

No additional changes beyond the original design:
- `paste(item: ClipboardItem)` signature already accepts the full item
- Keyboard event handler passes full `ClipboardItem` from `confirmSelection()` to `paste`

## Paste Flow

1. User copies content in any app
2. `checkForChanges()` detects type by priority: file → rich text → image → plain text
3. Content stored as the matching `ClipboardContentType` variant
4. User opens QuickCV panel (Cmd+Shift+V)
5. Sees appropriate preview in list
6. Selects and presses Enter (or clicks)
7. Original format written back to NSPasteboard via `copyToClipboard`
8. Panel hides, Cmd+V simulated to paste into target app

## Files to Modify

- `Sources/QuickCV/ClipboardManager.swift` — data model, detection priority, copy logic
- `Sources/QuickCV/ContentView.swift` — UI rendering for file/rich text items, search filtering
- `Sources/QuickCV/WindowManager.swift` — no additional changes beyond original design
