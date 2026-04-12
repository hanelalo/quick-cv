import SwiftUI
import AppKit

// MARK: - Design Tokens

private enum Tokens {
    // Background
    static let bgPrimary     = Color(hex: "FAFAFA")
    static let bgSecondary   = Color(hex: "F3F3F5")
    static let bgTertiary    = Color(hex: "EAEAEE")
    static let bgElevated    = Color(hex: "FFFFFF")

    // Accent — warm amber → coral gradient
    static let accent1       = Color(hex: "F59E0B") // amber
    static let accent2       = Color(hex: "EF4444") // red
    static let accentGradient = LinearGradient(
        colors: [accent1, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Text
    static let textPrimary   = Color(hex: "18181B")
    static let textSecondary = Color(hex: "52525B")
    static let textTertiary  = Color(hex: "A1A1AA")
    static let textMuted     = Color(hex: "D4D4D8")

    // Selection
    static let selectGradient = LinearGradient(
        colors: [Color(hex: "7C3AED"), Color(hex: "4F46E5")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Border
    static let border        = Color(hex: "E4E4E7")
    static let borderLight   = Color(hex: "D4D4D8")

    // Radius
    static let radiusItem: CGFloat = 12
    static let radiusSmall: CGFloat = 8
}

// MARK: - ContentView

struct ContentView: View {
    @ObservedObject var manager: ClipboardManager
    @State private var searchText = ""
    @State private var isSearchMode = false
    @State private var hoveredIndex: Int? = nil

    private var filteredHistory: [(Int, ClipboardItem)] {
        let enumerated = Array(manager.history.enumerated())
        if searchText.isEmpty {
            return enumerated
        }
        return enumerated.filter { $0.1.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Tokens.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                Divider().overlay(Tokens.border)

                if manager.history.isEmpty {
                    emptyStateView
                } else if filteredHistory.isEmpty {
                    noResultsView
                } else {
                    clipListView
                }

                footerView
            }
        }
        .frame(width: 480, height: 680)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Tokens.borderLight, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onAppear {
            WindowManager.onToggleSearch = { [self] in
                toggleSearch()
            }
        }
    }

    private var appLogoView: some View {
        Group {
            if let nsImage = Bundle.main.image(forResource: "logo") {
                Image(nsImage: nsImage)
                    .resizable()
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.accentGradient)
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func toggleSearch() {
        isSearchMode.toggle()
        WindowManager.isSearchActive = isSearchMode
        if !isSearchMode {
            searchText = ""
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            if isSearchMode {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.accent1)

                    SearchBarWrapper(text: $searchText) {
                        isSearchMode = false
                        searchText = ""
                        WindowManager.isSearchActive = false
                    }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Tokens.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.radiusSmall, style: .continuous)
                        .fill(Tokens.bgTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.radiusSmall, style: .continuous)
                                .strokeBorder(Tokens.accent1.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                appLogoView

                Text("QuickCV")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.textPrimary)
            }

            Spacer()

            Button(action: {
                manager.clear()
                searchText = ""
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Tokens.bgTertiary)
                    )
            }
            .buttonStyle(.plain)
            .help("清空历史")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Tokens.bgSecondary)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Tokens.textMuted)

            VStack(spacing: 6) {
                Text("暂无记录")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.textSecondary)

                Text("复制内容后将自动出现在此处")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Tokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(Tokens.textMuted)

            Text("没有匹配的结果")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Clip List

    private var clipListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                clipListContent
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .onChange(of: manager.selectedIndex) { newIndex in
                if let newIndex = newIndex {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    private var clipListContent: some View {
        LazyVStack(spacing: 4) {
            ForEach(filteredHistory, id: \.0) { index, item in
                clipItemRow(for: index, item: item)
                    .id(index)
            }
        }
    }

    private func clipItemRow(for index: Int, item: ClipboardItem) -> some View {
        ClipItemView(
            item: item,
            isSelected: manager.selectedIndex == index,
            isHovered: hoveredIndex == index,
            index: index,
            onHover: { isHovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    hoveredIndex = isHovering ? index : nil
                }
            }
        ) {
            WindowManager.shared.paste(item: item.content)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 20) {
            footerHint(key: "↑↓", label: "导航")
            footerHint(key: "↵", label: "粘贴")
            footerHint(key: "⌘K", label: "搜索")
            footerHint(key: "esc", label: "关闭")

            Spacer()

            Text("\(manager.history.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.textMuted)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Tokens.bgSecondary)
    }

    private func footerHint(key: String, label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Tokens.bgElevated)
                )

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.textMuted)
        }
    }
}

// MARK: - Clip Item

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
                    Text(item.content)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(isSelected ? .white : Tokens.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text(item.sourceAppName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? Tokens.accent1 : Tokens.textTertiary)

                        Circle()
                            .fill(isSelected ? Tokens.accent1.opacity(0.4) : Tokens.textMuted)
                            .frame(width: 3, height: 3)

                        Text("\(item.content.count) 字符")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Tokens.textTertiary)
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

// MARK: - Color Helper

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Search Bar

struct SearchBarWrapper: NSViewRepresentable {
    @Binding var text: String
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FocusSearchField {
        let wrapper = FocusSearchField()
        wrapper.textField.isBordered = false
        wrapper.textField.drawsBackground = false
        wrapper.textField.focusRingType = .none
        wrapper.textField.font = .systemFont(ofSize: 13, weight: .regular)
        wrapper.textField.textColor = NSColor(hex: "18181B")
        wrapper.textField.placeholderString = "搜索..."
        wrapper.textField.appearance = nil
        wrapper.textField.cell?.sendsActionOnEndEditing = false
        wrapper.textField.delegate = context.coordinator
        context.coordinator.field = wrapper.textField
        return wrapper
    }

    func updateNSView(_ nsView: FocusSearchField, context: Context) {
        if context.coordinator.isEditing {
            context.coordinator.isEditing = false
            return
        }
        if nsView.textField.stringValue != text {
            nsView.textField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchBarWrapper
        weak var field: NSTextField?
        var isEditing = false

        init(_ parent: SearchBarWrapper) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            isEditing = true
            parent.text = field?.stringValue ?? ""
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let item = ClipboardManager.shared.confirmSelection() {
                    WindowManager.shared.paste(item: item.content)
                }
                return true
            }
            return false
        }
    }
}

/// NSView wrapper that auto-focuses the text field when added to a window
final class FocusSearchField: NSView {
    let textField = NSTextField()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.textField)
        }
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: (r, g, b) = (UInt64(int >> 8) * 17, UInt64(int >> 4 & 0xF) * 17, UInt64(int & 0xF) * 17)
        case 6: (r, g, b) = (UInt64(int >> 16), UInt64(int >> 8 & 0xFF), UInt64(int & 0xFF))
        case 8: (r, g, b) = (UInt64(int >> 16 & 0xFF), UInt64(int >> 8 & 0xFF), UInt64(int & 0xFF))
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(
            calibratedRed: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: 1.0
        )
    }
}
