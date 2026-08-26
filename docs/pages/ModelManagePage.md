---
name: model-manage-page
description: 模型管理页（ModelManagePage）。企业管理员维护本公司大模型配置：列表、搜索、使用、编辑、删除；需要改模型列表/滑动操作/分页逻辑时读这份文档。
page: ModelManagePage.swift
path: chat/chat/UI/Pages/ModelManagePage.swift
apis:
  - GET /service/chat/getModelList
  - DELETE /service/chat/deleteModel/{modelId}
---

# ModelManagePage（模型管理页）

## 1. 页面职责

`ModelManagePage` 是「公司维度的大模型配置中心」：把当前公司（`AppState.currentCompany`）下的所有 `ChatModel` 以列表卡片展示，支持关键词搜索、下拉刷新、左滑「使用 / 编辑 / 删除」三个操作，并作为 `AddModelPage`、`UpdateModelPage` 的父页面。

入口在 `HomePage` 的 ActionSheet 菜单里，**且只对管理员可见**（`HomePage` 里判断 `company.role ?? 0 > 0` 才追加「模型管理」按钮），本页自身不做二次权限校验。

「使用」只改客户端状态（`AppState.currentModel` + `current_model_id` 缓存），供后续聊天选模型使用；真正的模型增删改走 `/service/chat/...` 接口。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/ModelManagePage.swift`（约 606 行，含同文件内嵌 `SwipeableModelRow` 组件）
- **入口**：`HomePage` 以 `fullScreenCover(isPresented: $showModelManage) { ModelManagePage() }` 弹出（无外层 `NavigationView` 包裹，本页自带 `NavigationStack`）
- **出口**：
  - `AddModelPage(onModelAdded:)` —— `navigationDestination(isPresented: $showAddModelPage)`
  - `UpdateModelPage(model:onModelUpdated:)` —— `navigationDestination(isPresented: $navigateToUpdatePage)`
  - `dismiss()` 返回 `HomePage`
- **依赖组件**：内嵌 `SwipeableModelRow`（同文件）；系统 `UIAlertController`（删除确认）
- **依赖模型**：`ChatModel`
- **依赖服务**：`HTTPClient.shared.getModelList`、`HTTPClient.shared.deleteModel`、`AppState.shared`、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentCompany`、读写 `currentModel` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 关闭页面 |
| `models` | `[ChatModel]`（`@State`） | `[]` | 模型列表数据源 |
| `isLoading` | `Bool` | `false` | 首屏/重置加载态（显示 `ProgressView`） |
| `isLoadingMore` | `Bool` | `false` | 加载更多态 |
| `currentPage` | `Int` | `1` | 页码（**实际未传给接口**，见 10.1） |
| `pageSize` | `Int` | `20` | 每页条数（**实际未传给接口**，见 10.1） |
| `hasMoreData` | `Bool` | `true` | 是否还有下一页，控制列表底部加载指示器 |
| `searchText` | `String` | `""` | 搜索框文本 |
| `isSearching` | `Bool` | `false` | 是否处于搜索态（影响空状态文案与 keyword） |
| `searchWorkItem` | `DispatchWorkItem?` | `nil` | 搜索防抖任务句柄 |
| `isRefreshing` | `Bool` | `false` | 下拉刷新态 |
| `showAlert` | `Bool` | `false` | 通用提示弹窗开关 |
| `alertMessage` | `String` | `""` | 提示内容 |
| `showAddModelPage` | `Bool` | `false` | 跳转 `AddModelPage` |
| `activeSwipeModelId` | `String?` | `nil` | 当前左滑打开的行 ID（保证同时只开一行） |
| `navigateToUpdatePage` | `Bool` | `false` | 跳转 `UpdateModelPage` |
| `selectedModel` | `ChatModel?` | `nil` | 传给 `UpdateModelPage` 的模型 |

`SwipeableModelRow` 自身状态：`@ObservedObject appState`、`@State offset: CGFloat = 0`。

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   ├─ customNavigationBar        背景 whiteColor / 上下 middleMargin / 底部 1px grayColor.opacity(0.3)
   │    ├─ 返回 chevron.left（subColor，middleIcon）→ dismiss()
   │    ├─ 标题「模型管理」（middleFont / .black）
   │    └─ 右侧 plus 按钮（subColor）→ showAddModelPage = true
   ├─ searchBarView              胶囊输入框 高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
   │    ├─ magnifyingglass（smallIcon，grayColor）
   │    ├─ TextField(prompt: 「搜索模型」grayColor) .onChange → handleSearchTextChange
   │    └─ 非空时 xmark.circle.fill 清空按钮
   └─ ScrollView .refreshable { await refreshData() }
      └─ VStack(spacing: middleMargin) → modelListCardView（whiteColor + borderRadius 圆角）
         ├─ isLoading            → ProgressView（垂直 largeMargin）
         ├─ models.isEmpty       → emptyStateView
         └─ else                 → modelListView
             └─ LazyVStack(spacing: 0)
                ├─ ForEach(models.enumerated(), id: \.element.id) → SwipeableModelRow
                │    └─ 非末行追加 Divider().padding(.leading, middleMargin)
                └─ hasMoreData && !isLoadingMore && !isRefreshing → ProgressView().onAppear { loadMoreModels() }
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
├─ .navigationDestination(isPresented: $showAddModelPage) { AddModelPage(onModelAdded: { loadModelList(reset: true) }).navigationBarHidden(true) }
└─ .navigationDestination(isPresented: $navigateToUpdatePage) { if let model = selectedModel { UpdateModelPage(model: model, onModelUpdated: { loadModelList(reset: true) }).navigationBarHidden(true) } }

（NavigationStack 外层）.onAppear { loadModelList() } + .navigationBarHidden(true)
```

### 4.1 emptyStateView

`cpu` 图标（`Dimens.bigIcon`，`grayColor`）+ 文案：搜索态「未找到相关模型」，否则「暂无模型」；非搜索态额外显示「点击右上角「+」添加模型」（`normalFont - 2`）。

### 4.2 SwipeableModelRow（同文件内嵌）

```
SwipeableModelRow(model:isActiveSwipe:onSwipeStateChanged:onUse:onEdit:onDelete:)
rowHeight = Dimens.middleAvater + Dimens.middleMargin * 2   // 50 + 30 = 80
└─ ZStack
   ├─ 背景层 HStack(spacing: 0)（右对齐三按钮，白字 normalFont，撑满行高）
   │    ├─ 「使用」/「已使用」 宽 80，isCurrentModel ? grayColor : primaryColor，isCurrentModel 时 .disabled(true)
   │    ├─ 「编辑」 宽 70，背景 Colors.subColor
   │    └─ 「删除」 宽 70，背景 Colors.warnColor
   └─ 前景层（.background(whiteColor).offset(x: offset)）
      └─ VStack(alignment: .leading, spacing: smallIcon)
         ├─ HStack：模型名 `model.modelName`（normalFont，lineLimit(1)，truncationMode(.tail)）
         │    └─ isCurrentModel → 标签「当前使用中」（normalFont-4，primaryColor 字 + primaryColor.opacity(0.1) 底 + smallIcon 圆角）
         └─ 类型标签 `model.type`（normalFont-2，grayColor 字 + grayColor.opacity(0.2) 底）
      .highPriorityGesture(DragGesture)  仅允许左滑，最大 -actionButtonsWidth(= 80+70+70 = 220)
      .onTapGesture 已展开时点击复位
.frame(height: rowHeight).clipped()
.onChange(of: isActiveSwipe) 非激活且已展开 → resetOffset()
```

滑动松手阈值 `actionButtonsWidth / 2`（110）：超过则弹到 `-220` 并回调 `onSwipeStateChanged(model.id, true)`，否则 `resetOffset()`；动画 `.spring(response: 0.3, dampingFraction: 0.8)`，按钮点击前的复位用 `.easeOut(duration: 0.25)`。

## 5. 核心方法

### `loadModelList(reset: Bool = true)`
- **触发**：`onAppear`；`refreshData()`；`handleSearchTextChange` 防抖后；`loadMoreModels()`（`reset: false`）；`AddModelPage` / `UpdateModelPage` 成功回调（`reset: true`）
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { print("❌ 未找到公司ID"); return }`
  2. `reset == true` 时：`isLoading = true`、`currentPage = 1`、`models = []`、`hasMoreData = true`、`activeSwipeModelId = nil`
  3. `let keyword = isSearching ? searchText : ""`
  4. 调 `getModelList(companyId:keyword:)`，回调内 `DispatchQueue.main.async` 先把 `isLoading`、`isLoadingMore` 置 `false`
  5. 成功：`reset` 直接覆盖 `models`；否则按 `id` 去重后 `append`；再算 `hasMoreData = models.count < total`
- **失败处理**：`print("❌ 获取模型列表失败...")` + `alertMessage = error.localizedDescription` + `showAlert = true`
- **注意**：无公司 ID 时**只打印日志，不给用户任何提示**，页面停留在空状态。

### `loadMoreModels()`
- **触发**：列表底部 `ProgressView` 的 `onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData`；`isLoadingMore = true`；`currentPage += 1`；`loadModelList(reset: false)`
- **注意**：`currentPage` 自增后并未传给接口（`getModelList` 无分页参数），本质是重复拉同一份全量列表再去重，见 10.1。

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：`MainActor.run { isRefreshing = true; activeSwipeModelId = nil }` → `loadModelList(reset: true)` → `MainActor.run { isRefreshing = false }`
- **注意**：`loadModelList` 是回调式异步，`isRefreshing = false` 会在请求返回**之前**执行，下拉动画不等接口结束。

### `handleSearchTextChange(_ newValue: String)`
- **触发**：搜索框 `.onChange(of: searchText)`
- **步骤**：
  1. `searchWorkItem?.cancel()` 取消上一次防抖任务
  2. 文本为空 → `isSearching = false`，立即 `loadModelList(reset: true)` 并 return
  3. 否则 `isSearching = true`，新建 `DispatchWorkItem { loadModelList(reset: true) }`，`asyncAfter(deadline: .now() + 0.5)` 执行

### `useModel(_ model: ChatModel)`
- **触发**：左滑「使用」按钮
- **步骤**：`appState.saveCurrentModel(model)`（写 `currentModel` + `UserDefaults` key `current_model_id`）→ `alertMessage = "已切换模型"`、`showAlert = true` → 打印日志
- **失败处理**：无网络请求，无失败分支。

### `deleteModel(_ model: ChatModel)`
- **触发**：左滑「删除」按钮
- **步骤**：
  1. `appState.currentModel?.id == model.id` → 提示「当前使用中的模型不能删除」并 return
  2. 构造 UIKit `UIAlertController`（标题「确认删除」，消息 `确定要删除模型 "<modelName>" 吗？`），「取消」`.cancel` + 「确定」`.destructive → performDeleteModel(model)`
  3. 通过 `UIApplication.shared.connectedScenes.first as? UIWindowScene` 的 `windows.first?.rootViewController` present
- **注意**：这是 UIKit 弹窗而非 SwiftUI `alert`/`confirmationDialog`，见 10.1。

### `performDeleteModel(_ model: ChatModel)`
- **触发**：删除确认弹窗点「确定」
- **步骤**：调 `deleteModel(modelId:)`，主线程回调：
  - `deletedCount > 0` → 提示「删除成功」；`models.removeAll { $0.id == model.id }`；若删的是当前模型则 `appState.currentModel = nil`
  - `deletedCount <= 0` → 提示「删除失败」
- **失败处理**：`alertMessage = error.localizedDescription` + `showAlert = true`

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getModelList` | GET | `/service/chat/getModelList` | `onAppear` / 搜索 / 下拉刷新 / 加载更多 / 增删改回调 | `docs/api/chat.md` |
| 2 | `deleteModel` | DELETE | `/service/chat/deleteModel/{modelId}` | 左滑删除 → 确认 | `docs/api/chat.md` |

### 6.1 `getModelList`

- **Swift 签名**：
  ```swift
  func getModelList(
      companyId: String,
      keyword: String = "",
      completion: @escaping (Result<([ChatModel], Int), NetworkError>) -> Void
  )
  ```
- **APIEndpoint**：`.getModelList(String)`（`method` = `"GET"`；`path` 直接返回 `Constants.API.getModelList`，**关联值 companyId 在 path 里没被使用**）
- **请求**：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `companyId` | Query | String | 是 | 由 `HTTPClient` 的 `parameters` 拼进查询串（GET/DELETE 统一走 query） |
| `keyword` | Query | String | 否 | 非空才加入 `parameters`，后端按模型名模糊搜索 |

- **响应**：`BaseResponse<[ChatModel]>`，`data` 为模型数组，`total` 为总数。后端文档 `chat.md` 示例中 `total` 为 `null`，且 data 元素含 `disabled` 字段（客户端 `ChatModel` 未解析）。
- **UI 处理**：成功 → 覆盖/追加 `models`、重算 `hasMoreData`；失败 → `alert`。
- **鉴权**：`chat.md` 明确「除 `getModelList` 外，其余接口均需 token」，即本接口后端不要求鉴权，但客户端仍会带上 `Authorization` 头。

### 6.2 `deleteModel`

- **Swift 签名**：`func deleteModel(modelId: String, completion: @escaping (Result<Int, NetworkError>) -> Void)`
- **APIEndpoint**：`.deleteModel(String)`（`method` = `"DELETE"`；`path` = `Constants.API.deleteModel.replacingOccurrences(of: "{modelId}", with: modelId)`，占位符名一致，替换正常）
- **请求**：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `modelId` | Path | String | 是 | 拼进 `/service/chat/deleteModel/{modelId}` |
| `companyId` | Query | String | 后端要求 | **客户端未传**（`request` 调用时 `parameters` 为 nil），见 10.1 |

- **响应**：`BaseResponse<Int>`；客户端要求 `data` 非 nil 才算成功并回传 `Int`。后端文档删除模型的出参示例是 `"data": null`。
- **UI 处理**：见 `performDeleteModel`。

## 7. 数据模型

### 7.1 ChatModel（`Models/ChatModel.swift`）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 模型 ID（`Identifiable`） |
| `modelName` | `String` | 否 | 模型名称，列表第一行 |
| `type` | `String` | 否 | 模型类型，注释写「ollama 或 online」，列表第二行标签 |
| `baseUrl` | `String` | 否 | 模型 API 地址 |
| `apiKey` | `String?` | 是 | 在线模型的 API Key，本页不展示 |
| `companyId` | `String` | 否 | 所属公司 ID |
| `updateTime` / `createTime` | `String?` | 是 | 时间，本页不展示 |

`CodingKeys` 与字段同名（后端已由 `ResultUtil` 把 snake_case 转驼峰）。后端表 `chat_model` 还有 `disabled`（0/1），客户端模型未包含。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 导航栏 / 搜索栏底部分隔线 | `Colors.whiteColor` 底 + 1px `Colors.grayColor.opacity(0.3)` |
| 导航栏返回 / 加号图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont`，`.black` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，描边 `grayColor.opacity(0.5)`，图标 `Dimens.smallIcon` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 行高 | `Dimens.middleAvater + Dimens.middleMargin * 2` = 80 |
| 「使用」按钮 | 宽 80，`Colors.primaryColor`；已使用 `Colors.grayColor` |
| 「编辑」按钮 | 宽 70，`Colors.subColor` |
| 「删除」按钮 | 宽 70，`Colors.warnColor` |
| 「当前使用中」标签 | `normalFont - 4`，`primaryColor` + `primaryColor.opacity(0.1)` 底 |
| 类型标签 | `normalFont - 2`，`grayColor` + `grayColor.opacity(0.2)` 底 |
| 空状态 | `cpu` 图标 `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入与首屏

```
HomePage ActionSheet「模型管理」（仅 company.role ?? 0 > 0 可见）
  → fullScreenCover ModelManagePage()
  → NavigationStack.onAppear → loadModelList()
      companyId = currentCompany?.id ?? getCachedCompanyId()（缓存 key companyId_<userId>）
      → GET getModelList(companyId, keyword: "")
      → models 填充；hasMoreData = models.count < total
```

### 9.2 搜索

```
输入 → onChange → handleSearchTextChange
  空串   → isSearching = false → 立即 loadModelList(reset: true)
  非空串 → isSearching = true  → 取消旧 WorkItem → 0.5s 后 loadModelList(reset: true)（keyword = searchText）
清空按钮（xmark.circle.fill）→ searchText = "" → 同上空串分支
```

### 9.3 左滑三操作

```
左滑 > 110pt → 展开 220pt，onSwipeStateChanged(id, true) → activeSwipeModelId = id
（其它行的 isActiveSwipe 变 false → onChange 自动复位，保证只展开一行）
├─ 使用 → resetOffset() → useModel → AppState.saveCurrentModel（内存 + current_model_id）→ alert「已切换模型」
├─ 编辑 → resetOffset() → selectedModel = model; navigateToUpdatePage = true
│           → UpdateModelPage(model:) 成功回调 → loadModelList(reset: true)
└─ 删除 → resetOffset() → deleteModel
            ├─ 是当前使用模型 → alert「当前使用中的模型不能删除」
            └─ 否则 UIAlertController 确认 → performDeleteModel
                  → DELETE deleteModel/{modelId}
                  → data > 0：alert「删除成功」+ 本地移除（不重新拉列表）
```

### 9.4 新增模型

```
导航栏「+」→ showAddModelPage = true → AddModelPage(onModelAdded:)
  添加成功 → 用户点 alert「确定」→ onModelAdded?() → loadModelList(reset: true) → dismiss() 回本页
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；搜索框 `searchBarView`；空状态 `emptyStateView`；行内容与三按钮 `SwipeableModelRow.body`。
- **加字段**（例如展示 `baseUrl`）：`ChatModel` 加字段/`CodingKeys` → 确认后端 `getModelList` 返回该字段 → `SwipeableModelRow` 前景层加一行（注意 `rowHeight` 是写死的 80，需同步调大）。
- **加接口**：`Constants.API` 加路径 → `APIEndpoint` 加 case 并在 `path`/`method` 两个 switch 补全 → `HTTPClient` 加业务方法 → 页面调用。
- **改滑动按钮数量/宽度**：`SwipeableModelRow.actionButtonsWidth` 是 `80 + 70 + 70` 的硬编码求和，改按钮宽度必须同步改它，否则展开位移与按钮区不对齐。

### 10.1 已知坑

1. **`deleteModel` 少传 `companyId`**：后端文档 `chat.md` 第 4 条明确要求「Query：`companyId` + Path：`modelId`」，但 `HTTPClient.deleteModel` 调用 `request(endpoint: .deleteModel(modelId))` 时没有 `parameters`，请求只有路径参数。建议给 `deleteModel` 增加 `companyId` 入参并作为 query 传出。
2. **分页状态是死代码**：`currentPage` / `pageSize` 两个 `@State` 从未传给接口（`getModelList` 只接受 `companyId` + `keyword`，后端也无 `pageNum`/`pageSize`）。`loadMoreModels()` 只是把同一份全量列表再请求一次然后按 id 去重。
3. **潜在的加载更多死循环**：`hasMoreData = models.count < total`。若后端把 `total` 返回为「全库总数 > 本次返回条数」，去重后 `models.count` 不再增长，`hasMoreData` 恒为 `true`，底部 `ProgressView` 会持续 `onAppear` → 反复发请求。当前后端示例 `total` 为 `null`（→ `?? 0`）时 `hasMoreData` 立即变 `false`，反而掩盖了这个问题。
4. **删除成功判定与后端出参不一致**：客户端要求 `BaseResponse<Int>.data` 非 nil 且 `> 0`；后端文档删除模型出参示例为 `"data": null`。若后端确实返回 null，`HTTPClient` 会走 `.failure(.custom(message: response.msg ?? "删除模型失败"))`，用户看到"删除模型失败"但数据其实已删。需与后端对齐返回受影响行数。
5. **`appState.currentModel = nil` 绕过了缓存清理**：`performDeleteModel` 直接给 `@Published` 属性赋 nil，`UserDefaults` 的 `current_model_id` 仍是被删模型的 ID，下次读 `getCachedModelId()` 会拿到失效 ID。建议补一个 `AppState.clearCurrentModel()` 同时 `removeObject`。
6. **UIKit 弹窗取 scene 的方式不严谨**：`UIApplication.shared.connectedScenes.first as? UIWindowScene` 在多 scene（iPad 分屏）下不一定是前台 scene，且若 `rootViewController` 已有 presented VC 会静默失败（弹窗不出现，用户点删除没反应）。建议改成 SwiftUI 的 `confirmationDialog` / `alert`。
7. **无公司 ID 时静默失败**：`loadModelList` 的 `guard` 只 `print("❌ 未找到公司ID")`，界面显示「暂无模型」，用户无法区分是没数据还是状态异常。
8. **`.onAppear` 挂在 `NavigationStack` 外层**：从 `AddModelPage`/`UpdateModelPage` 返回不会重新触发 `loadModelList`，刷新完全依赖 `onModelAdded` / `onModelUpdated` 回调；新增子页面时若忘传回调，列表就不会更新（`PromptManagePage` 就踩了这个坑）。
9. **`navigationDestination` 里 `if let selectedModel`**：`selectedModel` 为 nil 时目标视图是空的（`if` 不成立），会推进一个空白页；同时 `selectedModel` 从不复位，仅靠先赋值再置 `navigateToUpdatePage = true` 的顺序保证正确。
10. **行高写死**：`rowHeight = Dimens.middleAvater + Dimens.middleMargin * 2`（80）配合 `.clipped()`，模型名+类型标签两行在大字体辅助功能设置下会被裁掉。
11. **`APIEndpoint.getModelList(String)` 的关联值形同虚设**：`path` 里没用它；`APIEndpoint.url(baseURL:)` 虽然会为 `.getModelList` 拼 `companyId` query，但 `HTTPClient.request` 走的是 `URLComponents(string: baseURL + endpoint.path)`，从不调用 `url(baseURL:)`。实际 `companyId` 靠 `parameters` 传出，关联值可以删。
12. **`refreshData()` 的 `await` 是假的**：`isRefreshing` 在回调式请求发出后立刻被置 `false`，下拉刷新指示器不会等真实响应。

## 相关文档

- [AddModelPage](AddModelPage.md)（新增模型）
- [UpdateModelPage](UpdateModelPage.md)（编辑模型）
- [PromptManagePage](PromptManagePage.md)（同构的提示词管理页）
- 后端接口：`docs/api/chat.md`
