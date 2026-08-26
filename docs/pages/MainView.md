---
name: main-view
description: 脚手架占位页（MainView）。Xcode 模板残留的占位视图，未接入主链路，与 ContentView.swift 同类；需要确认它是死代码或想把它接入导航时读这份文档。
page: MainView.swift
path: chat/chat/UI/Pages/MainView.swift
apis: []
---

# MainView（脚手架占位页）

## 1. 页面职责

`MainView` 是一个**脚手架占位页**，当前没有任何业务职责。它是最初 `App` 模板（`@main` 结构体默认生成的根视图）的残留，只显示一段欢迎文字，未接入登录/聊天主链路，也没有被任何页面引用。

> 与 `ContentView.swift`（同为 `import SwiftUI` 后的最小 `View` 模板残留）是同一性质，只是 `ContentView` 放在源码根，`MainView` 被移到了 `UI/Pages/`。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/MainView.swift`（约 25 行）
- **入口**：无（未被任何 `NavigationLink` / `sheet` / `fullScreenCover` / `navigationDestination` 引用）
- **出口**：无
- **依赖组件**：无
- **依赖模型**：无
- **依赖服务**：仅 `Colors.pageBackgroundColor` 与 `.themePrimary` / `.bigFont` 主题别名

## 3. 状态定义

无 `@State` / `@ObservedObject` / `@Binding` / `@Environment`。纯静态视图。

## 4. 视图结构

```
body: ZStack
├─ Colors.pageBackgroundColor.ignoresSafeArea()
└─ VStack
   ├─ Spacer()
   ├─ Text("Hellow SwiftUI")       // 注意拼写 "Hellow"（应为 "Hello"）
   │    .font(.system(size: .bigFont, weight: .medium))   // .bigFont = 30
   │    .foregroundColor(.themePrimary)                   // = Colors.primaryColor（琥珀橙）
   │    .padding()
   └─ Spacer()
.navigationTitle("Chat")
```

## 5. 核心方法

无任何方法。

## 6. 接口调用

无。不调用 `HTTPClient` 或 `WebSocketManager`。

## 7. 数据模型

无。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 文字颜色 | `.themePrimary`（`Color` 扩展别名，等价 `Colors.primaryColor`） |
| 字号 | `.bigFont`（`CGFloat` 扩展别名，等价 `Dimens.bigFont = 30`） |

> `MainView` 用的是旧式主题别名（`Color.themePrimary`、`CGFloat.bigFont`），而非项目现行写法（`Colors.primaryColor`、`Dimens.bigFont`）。两个别名在 `Theme/Colors.swift`、`Theme/Dimens.swift` 里仍保留，因此能编译，但与其他页面的主题引用风格不一致，进一步佐证它是早期模板残留。

## 9. 交互流程

无交互。静态展示，没有任何点击/手势/网络行为。

## 10. 二次开发指引

- **确认是否删除**：当前 `MainView` 与 `ContentView` 均未被引用，属于可清理的死代码。删除前建议先全局搜索 `MainView(` 确认无引用。
- **如需接入主链路**（把它变成真正的根/主页）：
  1. 在 `ChatApp`（`@main`）或 `WelcomePage` 里引用 `MainView()`（替换/新增 `fullScreenCover` 或 `navigationDestination`）。
  2. 按项目规范改用 `Colors.primaryColor`、`Dimens.bigFont`，去掉 `navigationTitle("Chat")`（项目其他页面用自定义导航栏或 `navigationBarHidden`）。
  3. 补状态、依赖与接口（如需），再按模板补齐 3/5/6/7 章节。

### 10.1 已知坑

1. **拼写错误**：`Text("Hellow SwiftUI")` 中 `Hellow` 应为 `Hello`。
2. **死代码/未接入**：`MainView` 与 `ContentView` 都是模板残留，未被主链路引用；`MainView` 仅靠 `#Preview` 之外无任何调用点。
3. **旧主题别名**：使用 `.themePrimary` / `.bigFont`（`Color`/`CGFloat` 扩展），与现行 `Colors.*` / `Dimens.*` 规范不一致，风格上属历史遗留。

## 相关文档

- 主链路入口见共享上下文模板的「全局导航主链路」；[HomePage](HomePage.md) 是实际聊天主页。
