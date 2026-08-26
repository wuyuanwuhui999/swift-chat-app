---
name: prompt-manage-page
description: 提示词管理页（PromptManagePage）。按租户维护提示词：列表、搜索、使用、弹窗编辑、删除；需要改提示词列表/分页/删除接口（存在真实 bug）时读这份文档。
page: PromptManagePage.swift
path: chat/chat/UI/Pages/PromptManagePage.swift
apis:
  - GET /service/prompt/getPromptList
  - PUT /service/prompt/updatePrompt
  - DELETE /service/prompt/deletePrompt/{promptId}
---

# PromptManagePage（提示词管理页）

## 1. 页面职责

`PromptManagePage` 管理**当前租户**（`AppState.currentTenant`）下的系统提示词：分页列表 + 关键词搜索 + 下拉刷新，左滑提供「使用 / 编辑 / 删除」三个操作。

- 「使用」把提示词写进 `AppState.currentPrompt` 并按租户维度缓存 `current_prompt_id_<tenantId>`，供 `HomePage` 聊天时作为 system prompt。
- 「编辑」用 `CustomDialog` 内嵌 `TextEditor` 就地修改，调 `updatePromptById`。
- 「删除」用 UIKit `UIAlertController` 二次确认后调 `deletePrompt`（**该接口客户端实现有 bug，见 10.1，当前不可用**）。

入口在 `HomePage` 的 ActionSheet 菜单「提示词管理」，所有角色都可见（与「模型管理」不同，不做管理员判断）。新增提示词跳 [AddPromptPage](AddPromptPage.md)。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/PromptManagePage.swift`（约 698 行，含同文件内嵌 `SwipeablePromptRow`）
- **入口**：`HomePage` 的
  `fullScreenCover(isPresented: $showPromptManage) { NavigationView { PromptManagePage().navigationBarHidden(true) } }`
  （外层已有 `NavigationView`，本页 body 内还有一层 `NavigationStack`，见 10.1）
- **出口**：
  - `AddPromptPage()` —— `navigationDestination(isPresented: $showAddPromptPage)`，**未传 `onPromptAdded` 回调**
  - `dismiss()` 返回 `HomePage`
- **依赖组件**：`UI/Components/CustomDialog.swift`（编辑弹窗）；内嵌 `SwipeablePromptRow`；系统 `UIAlertController`（删除确认）
- **依赖模型**：`Prompt`
- **依赖服务**：`HTTPClient.shared.getPromptList` / `updatePromptById` / `deletePrompt`、`AppState.shared`、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentTenant`，读写 `currentPrompt` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 关闭页面 |
| `prompts` | `[Prompt]`（`@State`） | `[]` | 列表数据源 |
| `isLoading` | `Bool` | `false` | 首屏/重置加载态 |
| `isLoadingMore` | `Bool` | `false` | 加载更多态 |
| `currentPage` | `Int` | `1` | 页码，作为 `pageNum` 真实传给接口 |
| `pageSize` | `Int` | `20` | 每页条数，真实传给接口 |
| `hasMoreData` | `Bool` | `true` | 是否还有下一页 |
| `searchText` | `String` | `""` | 搜索框文本 |
| `isSearching` | `Bool` | `false` | 搜索态（影响空状态文案与 keyword） |
| `searchWorkItem` | `DispatchWorkItem?` | `nil` | 搜索防抖任务 |
| `isRefreshing` | `Bool` | `false` | 下拉刷新态 |
| `showEditDialog` | `Bool` | `false` | 编辑弹窗开关 |
| `editingPrompt` | `Prompt?` | `nil` | 正在编辑的提示词 |
| `editPromptText` | `String` | `""` | 编辑弹窗内文本 |
| `showAlert` | `Bool` | `false` | 通用提示弹窗 |
| `alertMessage` | `String` | `""` | 提示内容 |
| `showAddPromptPage` | `Bool` | `false` | 跳转 `AddPromptPage` |
| `activeSwipePromptId` | `String?` | `nil` | 当前左滑展开的行 ID |

`SwipeablePromptRow` 自身状态：`@ObservedObject appState`、`@State offset: CGFloat = 0`。

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   ├─ customNavigationBar        whiteColor 底 / 上下 middleMargin / 底部 1px grayColor.opacity(0.3)
   │    ├─ 返回 chevron.left（subColor，middleIcon）→ dismiss()
   │    ├─ 标题「提示词管理」（middleFont / .black）
   │    └─ 右侧 plus（subColor）→ showAddPromptPage = true
   ├─ searchBarView              高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
   │    ├─ magnifyingglass（smallIcon，grayColor）
   │    ├─ TextField("搜索提示词", text: $searchText) .onChange → handleSearchTextChange
   │    └─ 非空时 xmark.circle.fill 清空
   └─ ScrollView .refreshable { await refreshData() }
      └─ VStack(spacing: middleMargin) → promptListCardView（whiteColor + borderRadius）
         ├─ isLoading         → ProgressView（垂直 largeMargin）
         ├─ prompts.isEmpty   → emptyStateView（text.quote 图标 + 「未找到相关提示词」/「暂无提示词」）
         └─ else              → promptListView
             └─ LazyVStack(spacing: 0)
                ├─ ForEach(prompts.enumerated(), id: \.element.id) → SwipeablePromptRow
                │    └─ 非末行 Divider().padding(.leading, middleMargin)
                └─ hasMoreData && !isLoadingMore && !isRefreshing → ProgressView().onAppear { loadMorePrompts() }
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
├─ .navigationDestination(isPresented: $showAddPromptPage) { AddPromptPage().navigationBarHidden(true) }
└─ .overlay(editPromptDialog)

（NavigationStack 外层）.onAppear { loadPromptList() } + .navigationBarHidden(true)
```

### 4.1 editPromptDialog（`@ViewBuilder`，overlay）

`showEditDialog && editingPrompt != nil` 时渲染 `CustomDialog`：

```
CustomDialog(isPresented: $showEditDialog, title: "编辑提示词",
             content: { ZStack(topLeading) { TextEditor + 占位文字 } },
             onConfirm: { handleUpdatePrompt() },
             onCancel:  { showEditDialog = false; editingPrompt = nil; editPromptText = "" })
```

- `TextEditor(text: $editPromptText)`：`normalFont`、`minHeight: 200`、`maxHeight: .infinity`、内边距 `middleMargin`、`scrollContentBackground(.hidden)` + `.background(.white)`、`borderRadius` 圆角 + `Colors.grayColor` 1px 描边。
- 占位文字「请输入提示词内容...」：`editPromptText.isEmpty` 时显示，`grayColor`，`padding(.horizontal, middleMargin + 5)` / `padding(.vertical, middleMargin + 8)`，`allowsHitTesting(false)`。
- `CustomDialog` 自身（`UI/Components/CustomDialog.swift`）：`Color.black.opacity(0.5)` 遮罩（点击 = 取消）+ 标题 `middleFont` + 内容 + 「取消 / 确定」按钮（高 `btnHeight`、圆角 `btnHeight/2`）。

### 4.2 SwipeablePromptRow（同文件内嵌）

```
SwipeablePromptRow(prompt:isActiveSwipe:onSwipeStateChanged:onUse:onEdit:onDelete:)
rowHeight = Dimens.middleAvater + Dimens.middleMargin * 2   // 50 + 30 = 80
└─ ZStack
   ├─ 背景层 HStack(spacing: 0)：Spacer + 三个按钮（白字 normalFont，撑满行高）
   │    ├─ 「使用」/「已使用」宽 80，isCurrentPrompt ? grayColor : primaryColor，isCurrentPrompt 时 disabled
   │    ├─ 「编辑」宽 70，Colors.subColor
   │    └─ 「删除」宽 70，Colors.warnColor
   └─ 前景层 VStack(alignment: .leading, spacing: smallIcon)（whiteColor 底，offset(x:)）
      ├─ Text(prompt.prompt)  normalFont / .black / lineLimit(2) / truncationMode(.tail)
      └─ isCurrentPrompt → 「当前使用中」标签（normalFont-4，primaryColor + opacity(0.1) 底，smallIcon 圆角）
      .highPriorityGesture(DragGesture) 仅左滑，最大 -actionButtonsWidth（80+70+70 = 220）
      .onTapGesture 已展开则复位
.frame(height: rowHeight).clipped()
.onChange(of: isActiveSwipe) 非激活且展开 → resetOffset()
```

`actionButtonsWidth` 用 `var width: CGFloat = 0; width += 80; width += 70; width += 70` 累加（与 `SwipeableModelRow` 的一行求和写法不同，结果相同）。松手阈值 `actionButtonsWidth / 2`（110），动画 `.spring(response: 0.3, dampingFraction: 0.8)`。

## 5. 核心方法

### `loadPromptList(reset: Bool = true)`
- **触发**：`onAppear`、`refreshData()`、搜索防抖、`loadMorePrompts()`（`reset: false`）、`handleUpdatePrompt` 成功后
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id else { print("❌ 未找到租户ID"); return }`
  2. `reset` 时：`isLoading = true`、`currentPage = 1`、`prompts = []`、`hasMoreData = true`、`activeSwipePromptId = nil`
  3. `let keyword = isSearching ? searchText : ""`
  4. 调 `getPromptList(tenantId:keyword:pageNum: currentPage, pageSize: pageSize)`
  5. 主线程回调：`isLoading = false`、`isLoadingMore = false`
     - 成功：`reset` 覆盖 `prompts`，否则按 `id` 去重 `append`；`hasMoreData = prompts.count < total`
- **失败处理**：`print` + `alertMessage` + `showAlert`
- **注意**：无租户时只打印日志，界面显示「暂无提示词」。

### `loadMorePrompts()`
- **触发**：列表底部 `ProgressView.onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData` → `isLoadingMore = true` → `currentPage += 1` → `loadPromptList(reset: false)`

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：`MainActor.run { isRefreshing = true; activeSwipePromptId = nil }` → `loadPromptList(reset: true)` → `MainActor.run { isRefreshing = false }`（不等接口返回）

### `handleSearchTextChange(_ newValue: String)`
- 取消旧 `searchWorkItem`；空串 → `isSearching = false` 并立即 `loadPromptList(reset: true)`；非空 → `isSearching = true` + 0.5s 防抖后 `loadPromptList(reset: true)`。

### `usePrompt(_ prompt: Prompt)`
- **触发**：左滑「使用」
- **步骤**：
  1. `appState.updatePrompt(Prompt(id:tenantId:userId:prompt:createTime:updateTime:))` —— 用原字段逐个重建了一个等价 `Prompt`（多余但无害）
  2. 若有 `appState.currentTenant?.id` → `appState.saveCurrentPromptId(prompt.id, tenantId: tenantId)`（写 `UserDefaults`，key = `current_prompt_id_` + tenantId），否则打印「⚠️ 未找到租户ID，无法保存提示词缓存」
  3. `alertMessage = "已应用提示词"`、`showAlert = true`
- **失败处理**：无网络请求。注意 `AppState.updatePrompt` 只改内存 `currentPrompt`，缓存由第 2 步单独写。

### `showEditPrompt(_ prompt: Prompt)`
- **触发**：左滑「编辑」
- **步骤**：`editingPrompt = prompt` → `editPromptText = prompt.prompt` → `showEditDialog = true`

### `handleUpdatePrompt()`
- **触发**：`CustomDialog` 的 `onConfirm`
- **步骤**：
  1. `guard let prompt = editingPrompt else { return }`
  2. `editPromptText` trim 后为空 → `alertMessage = "提示词不能为空"` + `showAlert` + return
  3. `guard let tenantId = appState.currentTenant?.id else { alert「未找到租户ID」; return }`
  4. 调 `updatePromptById(id: prompt.id, prompt: trimmedText, tenantId: tenantId)`
  5. 主线程回调：
     - `success == true` → 「更新成功」+ `showEditDialog = false` + `editingPrompt = nil` + `editPromptText = ""` + `loadPromptList(reset: true)`
     - `success == false` → 「更新失败」
- **失败处理**：`alertMessage = error.localizedDescription` + `showAlert`
- **注意**：`CustomDialog` 的「确定」按钮点击时组件内部也会把 `isPresented` 置 false（见组件实现），失败分支里 `showEditDialog` 不会被本方法重新打开，编辑内容会丢。

### `deletePrompt(_ prompt: Prompt)`
- **触发**：左滑「删除」
- **步骤**：构造 UIKit `UIAlertController`（标题「确认删除」，消息「确定要删除该提示词吗？」）→「取消」`.cancel` /「确定」`.destructive → performDeletePrompt(prompt)`；通过 `UIApplication.shared.connectedScenes.first as? UIWindowScene` 的 `windows.first?.rootViewController` present。
- **注意**：与 `ModelManagePage.deleteModel` 不同，这里**没有**「当前使用中不能删除」的保护。

### `performDeletePrompt(_ prompt: Prompt)`
- **触发**：删除确认弹窗「确定」
- **步骤**：调 `deletePrompt(promptId: prompt.id)`：
  - `deletedCount > 0` → 「删除成功」+ `prompts.removeAll { $0.id == prompt.id }`；若删的是当前提示词 → `appState.currentPrompt = nil`
  - 否则 → 「删除失败」
- **失败处理**：`alertMessage = error.localizedDescription` + `showAlert`
- **注意**：此路径当前**必然失败**，原因见 10.1 第 1 条。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getPromptList` | GET | `/service/prompt/getPromptList` | `onAppear` / 搜索 / 刷新 / 加载更多 / 编辑成功 | `docs/api/prompt.md` |
| 2 | `updatePromptById` | PUT | `/service/prompt/updatePrompt` | 编辑弹窗「确定」 | `docs/api/prompt.md` |
| 3 | `deletePrompt` | DELETE | `/service/prompt/deletePrompt/{promptId}` | 删除确认「确定」 | `docs/api/prompt.md` |

### 6.1 `getPromptList`

- **Swift 签名**：
  ```swift
  func getPromptList(
      tenantId: String,
      keyword: String = "",
      pageNum: Int = 1,
      pageSize: Int = 20,
      completion: @escaping (Result<([Prompt], Int), NetworkError>) -> Void
  )
  ```
- **APIEndpoint**：`.getPromptList`（`path` = `Constants.API.getPromptList`；`method` = `"GET"`）
- **请求**（GET → 全部作为 Query）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `tenantId` | Query | String | 是 | 当前租户 |
| `pageNum` | Query | Int | 是 | 客户端总是传 `currentPage` |
| `pageSize` | Query | Int | 是 | 客户端固定 20（后端默认 10，最大 100） |
| `keyword` | Query | String | 否 | 非空才加入 |

- **响应**：`BaseResponse<[Prompt]>`，`data` 为提示词数组，`total` 为总数（后端 `prompt.md` 示例 `total: 100`）。
- **UI 处理**：覆盖/追加 `prompts`、重算 `hasMoreData`；失败弹 alert。

### 6.2 `updatePromptById`

- **Swift 签名**：`func updatePromptById(id: String, prompt: String, tenantId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void)`
- **APIEndpoint**：`.updatePrompt`（`path` = `Constants.API.updatePrompt` = `/service/prompt/updatePrompt`；`method` = `"PUT"`）
- **请求**（PUT → JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `id` | Body | String | 是 | 提示词 ID（后端 `UpdatePromptSchema` 字段表未列出，见 10.1） |
| `prompt` | Body | String | 是 | 新内容（已 trim） |
| `tenantId` | Body | String | 是 | 租户 ID |

- **响应**：`BaseResponse<Int>`，内部把 `data > 0` 转成 `Bool` 回调。后端文档「更新提示词」出参示例为 `"data": null`。
- **注意**：`HTTPClient` 里还有另一个同名家族方法 `updatePrompt(prompt: Prompt, completion: (Result<Prompt, NetworkError>) -> Void)`（只提交 `id`/`tenantId`/`userId`，不含 `prompt` 内容），**本页不使用**，别调错。

### 6.3 `deletePrompt`

- **Swift 签名**：`func deletePrompt(promptId: String, completion: @escaping (Result<Int, NetworkError>) -> Void)`
- **APIEndpoint**：`.deletePrompt(String)`（`method` = `"DELETE"`）；`path` 实现（`APIEndpoints.swift`）：
  ```swift
  case .deletePrompt(let promptId):
      return Constants.API.deletePrompt
          .replacingOccurrences(of: "{tenantId}", with: promptId)   // ⚠️ 占位符名不匹配
  ```
  而 `Constants.API.deletePrompt = "/service/prompt/deletePrompt/{promptId}"` —— 字符串里没有 `{tenantId}`，替换是空操作。
- **请求**：客户端只有 Path 一段（且未被替换），无 Query、无 Body。
- **后端要求**：`prompt.md` 第 4 条为 `DELETE /service/prompt/deletePrompt/{promptId}/{tenantId}`，**两段 Path 参数**。
- **响应**：`BaseResponse<Int>`，客户端要求 `data` 非 nil 才算成功；后端示例 `"data": null`。
- **结论**：这条链路当前不可用，详见 10.1 第 1 条与修复建议。

## 7. 数据模型

### 7.1 Prompt（`Models/Prompt.swift`）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 提示词 ID（`Identifiable`） |
| `tenantId` | `String` | 否 | 所属租户 |
| `userId` | `String` | 否 | 创建者用户 ID |
| `prompt` | `String` | 否 | 提示词正文（列表 `lineLimit(2)` 展示） |
| `createTime` | `String?` | 是 | 创建时间（本页不展示） |
| `updateTime` | `String?` | 是 | 更新时间（本页不展示） |

后端表 `prompt`：`id` / `prompt`（**varchar(255)**）/ `tenant_id` / `user_id` / `create_time` / `update_time`，其中 `id`、`tenant_id`、`user_id` 三列共同构成主键。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 导航栏 / 搜索栏分隔线 | `Colors.whiteColor` 底 + 1px `Colors.grayColor.opacity(0.3)` |
| 返回 / 加号图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，描边 `grayColor.opacity(0.5)` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 行高 | `Dimens.middleAvater + Dimens.middleMargin * 2` = 80，`.clipped()` |
| 「使用」按钮 | 宽 80，`Colors.primaryColor`；已使用 `Colors.grayColor` |
| 「编辑」按钮 | 宽 70，`Colors.subColor` |
| 「删除」按钮 | 宽 70，`Colors.warnColor` |
| 「当前使用中」标签 | `normalFont - 4`，`primaryColor` + `primaryColor.opacity(0.1)` |
| 编辑弹窗输入框 | `minHeight: 200`，`Dimens.borderRadius` 圆角 + `Colors.grayColor` 1px 描边 |
| 空状态 | `text.quote` 图标 `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入与首屏

```
HomePage ActionSheet「提示词管理」→ showPromptManage = true
  → fullScreenCover { NavigationView { PromptManagePage() } }
  → NavigationStack.onAppear → loadPromptList()
      tenantId = appState.currentTenant?.id（无则只打印日志）
      → GET getPromptList(tenantId, keyword: "", pageNum: 1, pageSize: 20)
      → prompts 填充；hasMoreData = prompts.count < total
```

### 9.2 分页 / 搜索 / 刷新

```
滑到底部 ProgressView.onAppear → loadMorePrompts → currentPage += 1 → loadPromptList(reset: false)（按 id 去重 append）
输入关键词 → 0.5s 防抖 → isSearching = true → loadPromptList(reset: true)（currentPage 重置为 1，keyword 生效）
清空关键词 → isSearching = false → 立即重载
下拉 → refreshData → 收起已展开行 + loadPromptList(reset: true)
```

### 9.3 使用 / 编辑 / 删除

```
左滑 > 110pt → 展开 220pt（activeSwipePromptId 保证只展开一行）
├─ 使用 → usePrompt
│     → AppState.updatePrompt(重建的 Prompt)  内存 currentPrompt
│     → AppState.saveCurrentPromptId(id, tenantId:)  UserDefaults current_prompt_id_<tenantId>
│     → alert「已应用提示词」
├─ 编辑 → showEditPrompt → editingPrompt/editPromptText 赋值 → CustomDialog overlay
│     └─ 确定 → handleUpdatePrompt
│           ├─ 空内容 → alert「提示词不能为空」
│           ├─ 无租户 → alert「未找到租户ID」
│           └─ PUT updatePrompt { id, prompt, tenantId }
│                 成功 → alert「更新成功」+ 关弹窗 + 清状态 + loadPromptList(reset: true)
│     └─ 取消 / 点遮罩 → 关弹窗 + editingPrompt = nil + editPromptText = ""
└─ 删除 → UIAlertController 确认 → performDeletePrompt
      → DELETE /service/prompt/deletePrompt/{promptId}（⚠️ 占位符未被替换，见 10.1）
      → 期望：data > 0 → alert「删除成功」+ 本地移除 + 若为当前提示词则 currentPrompt = nil
```

### 9.4 新增提示词

```
导航栏「+」→ showAddPromptPage = true → navigationDestination → AddPromptPage()（未传回调）
  AddPromptPage 添加成功 → 点 alert「确定」→ onPromptAdded?()（为 nil，什么都不做）→ dismiss()
  → 返回本页：列表**不会**自动刷新（.onAppear 挂在 NavigationStack 外层，pop 不触发）
  → 用户必须手动下拉刷新或改一次搜索词才能看到新数据
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；搜索框 `searchBarView`；空状态 `emptyStateView`；编辑弹窗 `editPromptDialog`；行与三按钮 `SwipeablePromptRow.body`。
- **加字段**：`Prompt` 模型 → 后端 `getPromptList` 返回 → `SwipeablePromptRow` 前景层（注意行高写死 80）。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method` 两个 switch）→ `HTTPClient` 方法 → 页面调用。
- **让新增后自动刷新**：把父页面的跳转改成 `AddPromptPage(onPromptAdded: { loadPromptList(reset: true) })`（`AddPromptPage` 已经支持该构造参数，只是没被用上）。

### 10.1 已知坑

1. **【严重】`deletePrompt` 路径占位符名写错，promptId 永远不会被替换**（已逐字核对源码）：
   - `Constants.swift`：`static let deletePrompt = "/service/prompt/deletePrompt/{promptId}"`
   - `APIEndpoints.swift`：
     ```swift
     case .deletePrompt(let promptId):
         return Constants.API.deletePrompt
             .replacingOccurrences(of: "{tenantId}", with: promptId)
     ```
     要替换的是 `{tenantId}`，而常量里的占位符是 `{promptId}` —— 找不到匹配，`replacingOccurrences` 原样返回，最终 path 是字面量 `/service/prompt/deletePrompt/{promptId}`。
   - 后果：`HTTPClient.request` 里 `URLComponents(string: baseURL + endpoint.path)` 拿到含 `{`、`}` 的非法 URL 字符串 —— 解析失败时直接 `completion(.failure(.invalidURL))`（用户看到一条无意义的错误提示，因为 `NetworkError` 没有实现 `LocalizedError`，`error.localizedDescription` 是系统兜底文案）；即便某些系统版本容忍非法字符，请求也会带着字面量 `{promptId}` 发出，后端匹配不到真实 ID。**结论：删除提示词功能完全不可用。**
   - **同时与后端路径不一致**：`docs/api/prompt.md` 定义的是 `DELETE /service/prompt/deletePrompt/{promptId}/{tenantId}`（Path 里 `promptId` + `tenantId` 两段），客户端常量只有一段。
   - **修复建议**（三处一起改）：
     ```swift
     // Constants.swift
     static let deletePrompt = "/service/prompt/deletePrompt/{promptId}/{tenantId}"

     // APIEndpoints.swift：关联值改成两个
     case deletePrompt(String, String)   // (promptId, tenantId)
     case .deletePrompt(let promptId, let tenantId):
         return Constants.API.deletePrompt
             .replacingOccurrences(of: "{promptId}", with: promptId)
             .replacingOccurrences(of: "{tenantId}", with: tenantId)

     // HTTPClient.swift
     func deletePrompt(promptId: String, tenantId: String, completion: ...) {
         request(endpoint: .deletePrompt(promptId, tenantId)) { ... }
     }
     ```
     并在 `performDeletePrompt` 里传 `appState.currentTenant?.id`（或 `prompt.tenantId`）。另建议给 `path` 加断言/单测，防止占位符再次写错。
2. **删除成功判定与后端出参不一致**：客户端要求 `BaseResponse<Int>.data` 非 nil 且 `> 0`；`prompt.md` 删除/新增/更新的出参示例都是 `"data": null`。若后端确实返回 null，`HTTPClient` 会走 `.failure(.custom(message: msg ?? "删除提示词失败"))`，即「操作其实成功了但提示失败」。`updatePromptById`（`data > 0` → `Bool`）同理。需与后端统一返回受影响行数。
3. **新增提示词后列表不刷新**：父页面 `navigationDestination` 里写的是 `AddPromptPage()`，**没有传 `onPromptAdded`**；而 `.onAppear { loadPromptList() }` 挂在 `NavigationStack` 外层，pop 回来不会重新触发。对比 `ModelManagePage` 传了 `onModelAdded` 回调。修法见上文「二次开发指引」。
4. **双层导航容器**：`HomePage` 用 `NavigationView { PromptManagePage().navigationBarHidden(true) }` 包了一层，本页 body 里又是 `NavigationStack`。两层嵌套下 `navigationDestination` 行为容易异常（返回手势、栈层级），且 `ModelManagePage` 的入口没有这层 `NavigationView`，两处不一致。
5. **后端 `UpdatePromptSchema` 未列 `id`**：`prompt.md` 的请求体字段表只有 `tenantId`、`prompt`，而 `updatePromptById` 提交了 `id`。文档需补齐（否则会以为更新是按 tenantId 覆盖）。
6. **删除后未清提示词缓存**：`performDeletePrompt` 只把 `appState.currentPrompt` 置 nil，没有调 `AppState.clearPromptCache(tenantId:)`，`UserDefaults` 的 `current_prompt_id_<tenantId>` 仍指向已删提示词，下次 `getCachedPromptId(tenantId:)` 会返回失效 ID。
7. **删除没有「当前使用中」保护**：`ModelManagePage` 会拦「当前使用中的模型不能删除」，本页可以直接删掉正在使用的提示词。
8. **`usePrompt` 里多余地重建 `Prompt`**：`appState.updatePrompt(Prompt(id: prompt.id, tenantId: ..., ...))` 逐字段复制出一个等价对象，直接传 `prompt` 即可；将来 `Prompt` 加字段时这里会漏拷。
9. **编辑失败会丢内容**：`CustomDialog` 的「确定」按钮内部会先 `isPresented = false`，`handleUpdatePrompt` 的失败分支只弹 alert、不重开弹窗，用户刚编辑的文本消失。
10. **UIKit 弹窗取 scene 不严谨**：`UIApplication.shared.connectedScenes.first as? UIWindowScene` 在多 scene 下不一定是前台；若 `rootViewController` 已经 present 了别的控制器（本页本身就是 `fullScreenCover` 里的内容），确认弹窗可能弹不出来，表现为「点删除没反应」。建议换 SwiftUI `confirmationDialog`。
11. **无租户时静默失败**：`loadPromptList` 的 `guard` 只 `print("❌ 未找到租户ID")`；`usePrompt` 无租户时也只打印警告，界面无任何反馈。
12. **搜索框与 `ModelManagePage` 风格不一致**：本页用 `TextField("搜索提示词", text:)`（label 当占位、系统默认灰），`ModelManagePage` 用 `prompt: Text("搜索模型").foregroundColor(Colors.grayColor)`，占位色不统一。
13. **行高写死 80 + `.clipped()`**：`lineLimit(2)` 的正文加上「当前使用中」标签在默认字号下已接近 80pt，大字号辅助功能会被裁切。
14. **`refreshData()` 的 `await` 是假的**：`isRefreshing = false` 在回调式请求返回前就执行，下拉指示器不等真实响应。
15. **提示词长度无校验**：后端表 `prompt.prompt` 是 `varchar(255)`，编辑弹窗与 [AddPromptPage](AddPromptPage.md) 都没有长度限制，超长内容会在后端报错。

## 相关文档

- [AddPromptPage](AddPromptPage.md)（新增提示词）
- [ModelManagePage](ModelManagePage.md)（同构的模型管理页，可对比回调/权限差异）
- 后端接口：`docs/api/prompt.md`
