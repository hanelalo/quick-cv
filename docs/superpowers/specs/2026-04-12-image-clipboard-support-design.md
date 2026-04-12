# Image Clipboard Support Design

**Date:** 2026-04-12
**Status:** Approved

## Goal

Add image clipboard support to QuickCV. Users can copy images (screenshots, copied images from browsers, etc.) and see thumbnail previews in the clipboard history panel. Selecting an image and pressing Enter pastes it into the target application.

## Requirements

- Support all image types from NSPasteboard (PNG, TIFF, BMP, GIF, PDF, etc.) via `NSImage(pasteboard:)`
- Display thumbnails in the history list
- Text items keep their existing 50-item limit; images get a separate 20-item limit
- Images stored in memory only (lost on app restart, consistent with current text behavior)
- No size limit on individual images
- Search filters text items only; images are hidden during search

## Data Model

### New enum

```swift
enum ClipboardContentType {
    case text(String)
    case image(NSImage)
}
```

### Updated ClipboardItem

```swift
struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: ClipboardContentType   // was: String
    let sourceAppName: String
    let sourceAppIcon: NSImage
    let timestamp: Date
}
```

## ClipboardManager Changes

1. **`history`** remains `[ClipboardItem]` with `content: ClipboardContentType`
2. **`checkForChanges()`** checks for images first via `NSImage(pasteboard:)`, then text. Only one type is captured per clipboard change.
3. **Image limit:** 20 images max. When exceeded, remove oldest image items.
4. **Text limit:** 50 text items max (unchanged).
5. **Dedup:** Text items deduplicated by string comparison. Image items not deduplicated.
6. **`copyToClipboard(item:)`** accepts `ClipboardItem`. Writes `.string` for text, `.png` for images.

## UI Changes

### ClipItemView

Both text and image items use the same `ClipItemView`, branching on `item.content`:

**Image items:**
- Left: source app icon (unchanged)
- Center: thumbnail (max height 80pt, width proportional, rounded corners)
- Metadata line: `sourceAppName · 图片 · WxH`
- Selection/hover behavior identical to text items

**Text items:**
- No changes to existing layout

### Search

- `filteredHistory` skips image items when search text is non-empty
- Image items visible only when search is inactive

## WindowManager Changes

1. **`paste(item:)`** signature: `paste(item: ClipboardItem)` instead of `paste(item: String)`
2. Keyboard event handler passes full `ClipboardItem` from `confirmSelection()` to `paste`
3. Search bar Enter key similarly passes full `ClipboardItem`

## Paste Flow

1. User copies image in any app
2. ClipboardManager detects change, reads image from NSPasteboard, stores as `.image(NSImage)`
3. User opens QuickCV panel (Cmd+Shift+V)
4. Sees image thumbnail in list
5. Selects and presses Enter (or clicks)
6. Image written back to NSPasteboard as PNG
7. Panel hides, Cmd+V simulated to paste into target app

## Files to Modify

- `Sources/QuickCV/ClipboardManager.swift` — data model, polling, copy logic
- `Sources/QuickCV/ContentView.swift` — UI rendering for image items, search filtering
- `Sources/QuickCV/WindowManager.swift` — paste signature, keyboard event handling
