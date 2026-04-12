# QuickCV

A lightweight and elegant clipboard history manager for macOS, built with SwiftUI.

## Features

- **Clipboard History**: Automatically saves your clipboard history for quick access
- **Smart Search**: Search through your clipboard history with real-time filtering
- **Keyboard Shortcuts**: Quick access with customizable keyboard shortcuts
- **Multi-format Support**: Handles text, rich text, files, and images
- **Auto-paste**: Automatically paste selected items with optional accessibility permission
- **Launch at Login**: Option to start automatically when you log in
- **Menu Bar Integration**: Convenient menu bar icon for quick access
- **Beautiful UI**: Modern, polished interface with smooth animations

## Requirements

- macOS 13.0 Ventura or later
- Xcode 14.0 or later (for building from source)

## Installation

### Pre-built App
Download `QuickCV.app` from the repository and drag it to your Applications folder.

### Build from Source
```bash
# Clone the repository
git clone https://github.com/hanelalo/quick-cv.git
cd quick-cv

# Build the app
swift build

# Or use the build script
./build_app.sh
```

## Usage

1. **Launch QuickCV** from your Applications folder or Applications menu
2. **Copy something** - QuickCV automatically tracks your clipboard
3. **Open history panel** with the default shortcut `Cmd+Shift+V` (customizable in settings)
4. **Navigate** using arrow keys `↑↓`
5. **Select and paste** by pressing `Enter`
6. **Search** with `Cmd+K` to find specific clipboard items
7. **Close** with `Esc`

### Settings

Access settings from the menu bar icon or by opening the app:
- Customize keyboard shortcuts
- Toggle launch at login
- Configure auto-paste behavior (requires Accessibility permission)

### Permissions

For auto-paste functionality, QuickCV may request Accessibility permission:
- Go to **System Settings → Privacy & Security → Accessibility**
- Enable QuickCV in the list

## Architecture

QuickCV is built using:
- **SwiftUI** for the user interface
- **AppKit** for macOS-specific features
- **KeyboardShortcuts** library for customizable shortcuts
- **ServiceManagement** framework for launch-at-login functionality

### Project Structure
```
Sources/QuickCV/
├── QuickCVApp.swift      # Main app entry and settings
├── ContentView.swift     # Main UI and clipboard list
├── ClipboardManager.swift # Clipboard monitoring and history
└── WindowManager.swift   # Panel window management
```

## Development

### Dependencies
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Native Swift library for global keyboard shortcuts

### Build Commands
```bash
# Build
swift build

# Run
swift run

# Clean build
swift package clean
```

## License

MIT License - see [LICENSE](LICENSE) file for details

## Author

hanelalo

## Acknowledgments

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus
- macOS SwiftUI community and documentation
