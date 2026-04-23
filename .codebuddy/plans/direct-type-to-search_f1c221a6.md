---
name: direct-type-to-search
overview: 实现面板打开后直接输入即可搜索的功能，无需先按 Cmd+K 唤醒搜索模式
todos:
  - id: modify-window-manager
    content: 修改 WindowManager.swift：添加 onStartSearchWithCharacter 回调，改造 default 分支拦截可打印字符自动激活搜索
    status: completed
  - id: modify-content-view
    content: 修改 ContentView.swift：添加 startSearchWithCharacter 方法，注册回调，更新底部提示文字
    status: completed
    dependencies:
      - modify-window-manager
---

## 用户需求

用户希望唤醒剪贴板历史面板后，直接输入文字就开始搜索，而不需要先按 Cmd+K 激活搜索模式。

## 核心功能

- 面板可见且未处于搜索模式时，用户按下可打印字符按键，自动进入搜索模式并将该字符作为搜索文本
- 搜索模式激活后，后续键盘输入正常由搜索框处理
- Escape 键行为不变：搜索模式中按 Escape 退出搜索，非搜索模式中按 Escape 关闭面板
- Cmd+K 仍保留作为搜索模式切换快捷键
- 底部提示更新，引导用户直接输入即可搜索

## 技术栈

- 语言：Swift（SwiftUI + AppKit）
- 框架：SwiftUI、AppKit、KeyboardShortcuts
- 最低版本：macOS 13.0

## 实现方案

通过在 WindowManager 的键盘事件监控器中拦截可打印字符按键，当面板可见且未处于搜索模式时，自动激活搜索模式并传入初始字符。具体涉及两个文件的修改：

### 关键技术决策

1. **事件拦截策略**：在 `NSEvent.addLocalMonitorForEvents` 的 `default` 分支中，检测无 Command/Control 修饰键的可打印字符，调用新增回调 `onStartSearchWithCharacter`，返回 `nil` 消费该事件
2. **搜索模式激活**：ContentView 新增 `startSearchWithCharacter(_:)` 方法，同时设置 `isSearchMode = true`、`searchText = char`、`WindowManager.isSearchActive = true`
3. **已激活搜索时的事件透传**：当 `isSearchActive` 为 true 时，`default` 分支直接 `return event`，让搜索框正常接收键盘输入
4. **可打印字符判定**：`event.characters` 非空且首字符不属于 `CharacterSet.controlCharacters`；不允许 Command 或 Control 修饰键，允许 Option（产生合法可打印字符如特殊符号）

## 目录结构

```
Sources/QuickCV/
├── WindowManager.swift    # [MODIFY] 添加 onstartSearchWithCharacter 回调，修改 default 分支拦截可打印字符
├── ContentView.swift      # [MODIFY] 添加 startSearchWithCharacter 方法，注册回调，更新底部提示
├── QuickCVApp.swift       # 无修改
└── ClipboardManager.swift # 无修改
```

## 修改细节

### WindowManager.swift

- 新增静态回调属性：`static var onStartSearchWithCharacter: ((String) -> Void)?`
- 修改 `default` 分支逻辑：

1. 保留 Cmd+K 切换搜索
2. 若 `isSearchActive` 为 true，直接 `return event`（让搜索框接收输入）
3. 若无 Command/Control 修饰键，且 `event.characters` 为可打印字符，调用 `onStartSearchWithCharacter` 并 `return nil`

### ContentView.swift

- 新增 `startSearchWithCharacter(_ char: String)` 方法：设置 `isSearchMode = true`、`searchText = char`、`WindowManager.isSearchActive = true`
- 在 `onAppear` 中注册 `WindowManager.onStartSearchWithCharacter` 回调
- 底部提示：将 `footerHint(key: "⌘K", label: "Search")` 改为 `footerHint(key: "Type", label: "Search")`