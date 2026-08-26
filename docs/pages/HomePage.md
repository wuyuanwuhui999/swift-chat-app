---
name: home-page
description: 聊天主页（HomePage），全项目最核心的页面。WebSocket 流式 AI 对话、租户/模型/提示词/文档上下文切换、会话历史加载都在这里；需要改动聊天主链路或排查流式消息问题时读这份文档。
page: HomePage.swift
path: chat/chat/UI/Pages/HomePage.swift
apis:
  - GET /service/tenant/getTenantList
  - GET /service/chat/getModelList
  - GET /service/prompt/getPrompt
  - GET /service/chat/getChatHistoryByChatId
  - WS /service/chat/ws/chat
---

# HomePage（聊天主页）

## 1. 页面职责

`HomePage` 是登录 → 选择公司之后进入的聊天主界面，负责整个「发消息 → 收 AI 流式回复」闭环。它是全项目**唯一不使用卡片式布局**的页面（规范里「除 ChatPage/HomePage 外」的例外指的就是它）：背景铺满 `Colors.pageBackgroundColor`，消息列表和输入栏直接纵向堆叠。

页面承载三类职责：

1. **AI 对话**：通过 `WebSocketManager.shared` 建立 WebSocket 连接，把用户输入连同当前租户/模型/公司/提示词/文档上下文发送出去，并流式追加 AI 回复。
2. **上下文管理**：顶部标题栏切换租户与模型（弹窗）、聊天区上方切换「深度思考 / 查询文档 / 中英文」、菜单里进入会话记录/文档/提示词/模型管理等。
3. **会话历史**：从菜单「会话记录」选择历史会话，按 `chatId` 拉取历史并回填到消息列表。

> 注：`HomePage` 名字在导航链路里实际承接了「ChatPage」的角色，但它没有抽独立的 ChatPage，历史文档（共享上下文模板）中提到的 ChatPage 即指本页。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/HomePage.swift`（约 587 行）
- **入口**：由 [CompanyPage](CompanyPage.md) 的 `navigationDestination(isPresented: $navigateToChat)` 推出（`NavigationStack` 内），首登选择公司后进入；`.navigationBarHidden(true)`。
- **出口**：
  - 头像点击 → `UserPage`（`fullScreenCover`，包在 `NavigationView` 内，`navigationBarHidden(true)`）
  - 菜单「提示词管理」→ `PromptManagePage`（`fullScreenCover` + `NavigationView`）
  - 菜单「模型管理」（仅管理员可见）→ `ModelManagePage`（`fullScreenCover`）
  - 弹窗：`TenantListPopup` / `ModelListPopup` / `DocumentPickerDialog` / `ChatHistoryDialog` / `UploadDocumentDialog` / `MyDocumentsDialog` / `PromptDialog`
- **依赖组件**：`ChatHeader`、`MessageBubble`（内部含 `MessageContentView`）、`MessageInputBar`、`ChatActionButtons`、`TenantListPopup`、`ModelListPopup`、`ChatHistoryDialog`、`DocumentPickerDialog`、`UploadDocumentDialog`、`MyDocumentsDialog`、`PromptDialog`；头像依赖 `UserAvatar` / `AIAvatar`。
- **依赖模型**：`ChatMessage`、`ChatHistory`、`ChatModel`、`Tenant`、`Prompt`、`Company`
- **依赖服务**：`HTTPClient.shared.getTenantList / getModelList / getPrompt / getChatHistoryByChatId`、`AppState.shared`、`WebSocketManager.shared`

## 3. 状态定义

### 3.1 @ObservedObject

| 属性 | 类型 | 作用 |
|---|---|---|
| `appState` | `AppState`（`AppState.shared`） | 全局状态：当前租户/模型/提示词/公司、租户列表、模型列表、用户数据 |
| `webSocketManager` | `WebSocketManager`（`WebSocketManager.shared`） | WebSocket 连接管理，发布 `currentResponse` / `isReceiving` |

### 3.2 @State

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `messages` | `[ChatMessage]` | `[]` | 消息列表（用户消息 + AI 消息，含占位） |
| `inputMessage` | `String` | `""` | 输入框文本（双向绑定到 `MessageInputBar`） |
| `showTenantList` | `Bool` | `false` | 租户列表弹窗 |
| `showModelList` | `Bool` | `false` | 模型列表弹窗 |
| `showMenu` | `Bool` | `false` | 右上角菜单 `ActionSheet` |
| `isLoading` | `Bool` | `false` | 加载覆盖层（租户/模型/历史加载） |
| `showThink` | `Bool` | `false` | 深度思考开关 |
| `language` | `String` | `"zh"` | 语言 `"zh"` / `"en"` |
| `currentChatId` | `String` | `""` | 当前会话 ID（UUID 去连字符 32 位） |
| `currentAIResponse` | `String` | `""` | 当前 AI 响应（流式追加缓冲） |
| `isReceivingMessage` | `Bool` | `false` | 是否正在接收流式消息 |
| `showDocumentQuery` | `Bool` | `false` | 「查询文档」激活态 |
| `showDocumentPicker` | `Bool` | `false` | 文档选择器弹窗 |
| `selectedDocIds` | `Set<String>` | `[]` | 已选文档 ID 集合 |
| `showChatHistory` | `Bool` | `false` | 会话记录弹窗 |
| `showUploadDocument` | `Bool` | `false` | 上传文档弹窗 |
| `showMyDocuments` | `Bool` | `false` | 我的文档弹窗 |
| `showUserPage` | `Bool` | `false` | 用户页 fullScreenCover |
| `showPromptDialog` | `Bool` | `false` | 提示词设置弹窗（**见 10.4，未挂载**） |
| `showPromptManage` | `Bool` | `false` | 提示词管理页 fullScreenCover |
| `showModelManage` | `Bool` | `false` | 模型管理页 fullScreenCover |

## 4. 视图结构

```
body: ZStack
├─ backgroundView                    Colors.pageBackgroundColor.ignoresSafeArea()
└─ VStack(spacing: 0)
   ├─ headerView                     ChatHeader
   ├─ chatMessagesView               ScrollViewReader → ScrollView → LazyVStack → ForEach(messages) { MessageBubble }
   ├─ ChatActionButtons              深度思考 / 查询文档 / 中英文
   └─ inputBarView                   MessageInputBar
├─ .onAppear                         loadTenantAndModel() + 生成 chatId
├─ .overlay(tenantListOverlay)       showTenantList → 半透明遮罩 + TenantListPopup
├─ .overlay(modelListOverlay)        showModelList → 半透明遮罩 + ModelListPopup
├─ .overlay(loadingOverlay)          isLoading → ProgressView（scaleEffect 1.5，黑色 0.3 遮罩）
├─ .overlay(documentPickerOverlay)   showDocumentPicker → DocumentPickerDialog
├─ .overlay(chatHistoryOverlay)      showChatHistory → ChatHistoryDialog
├─ .overlay(uploadDocumentOverlay)   showUploadDocument → UploadDocumentDialog
├─ .overlay(myDocumentsOverlay)      showMyDocuments → MyDocumentsDialog
├─ .fullScreenCover(showModelManage) ModelManagePage()
├─ .fullScreenCover(showUserPage)    NavigationView { UserPage() }
├─ .fullScreenCover(showPromptManage)NavigationView { PromptManagePage() }
├─ .actionSheet(showMenu)            menuActionSheet
├─ .onReceive(webSocketManager.$currentResponse)  流式更新最后一条 AI 消息
└─ .onReceive(webSocketManager.$isReceiving)      同步 isReceivingMessage / 结束重置
```

### 4.1 headerView —— ChatHeader

`ChatHeader`（`UI/Components/ChatHeader.swift`，72 行）props：

- `showTenantList` / `showModelList`：`@Binding Bool`，控制两个弹窗互斥（点租户关模型、点模型关租户）。
- `onAvatarTap: () -> Void`：头像点击 → 本页 `showUserPage = true`。
- `onMenuClick: () -> Void`：`line.horizontal.3` 图标 → `showMenu.toggle()`。

内部结构：`HStack` = 左头像（`UserAvatar` 或灰色 `Circle` 占位，`middleAvater`）+ 中间「租户名｜模型名」两个 `Button` + 右侧菜单图标。标题文案取 `appState.currentTenant?.name ?? "选择租户"` 与 `appState.currentModel?.modelName ?? "选择模型"`。背景 `whiteColor`。

### 4.2 chatMessagesView —— 消息列表

`ScrollViewReader` 包裹 `ScrollView`，`LazyVStack` 里 `ForEach(messages)` 渲染 `MessageBubble`。两个滚动锚点：

- `.onChange(of: messages.count)` → `scrollToBottom`
- `.onChange(of: messages.last?.content)` → `scrollToBottom`

`scrollToBottom` 用 `proxy.scrollTo(lastMessage.id, anchor: .bottom)`，`withAnimation`。

### 4.3 MessageBubble（组件，250 行）

`MessageBubble(message: ChatMessage)`（`UI/Components/MessageBubble.swift`）：

- 内部 `isEmptyContent`：`content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`。
- **用户消息**（`isUser == true`）：右对齐，`MessageContentView(content:isUser:alignToAvatar:)` + 时间戳（非空内容才显示）+ 右侧 `UserAvatar`，气泡带向右的 `Triangle` 箭头（`Colors.whiteColor`，12×12）。
- **AI 消息**：左对齐，`AIAvatar.middle()` + 内容 + 时间戳；**内容为空时显示 loading 态**（`ProgressView` + 「正在加载中...」白色圆角卡片），这就是发送时先插入的空占位消息。
- 时间格式：`DateFormatter` `"HH:mm"`。

`MessageContentView`（同文件内）：

- 用户消息：纯 `Text`，白底圆角。
- AI 消息：`parseContent` 解析 `<think>...</think>`，思考内容渲染成带 `brain` 图标 +「思考过程」标题的灰底块（`grayColor.opacity(0.1)`），正文单独 `Text`。
- `parseContent`：仅当 `content.hasPrefix("<think>")` 才解析；找不到 `</think>` 时整个内容当思考内容。

### 4.4 MessageInputBar（组件，78 行）

`MessageInputBar` props：

- `messageText: Binding<String>`；`isSending: Bool`（发送中禁用输入框 + 显示转圈）；`onSend`、`onClear`、`selectedDocCount: Int`、`showDocumentSelectionButton: Bool`、`onDocumentPicker`。

结构：左「清空」按钮（`plus.message`，绑 `onClear`）→ `TextField`（`axis: .vertical`，`lineLimit(1...5)`，白底 `inputHeight/2` 圆角）→ 条件显示 `DocumentSelectionButton`（`showDocumentQuery` 激活时才出现）→ 发送按钮（`paperplane.fill`，空文本灰、有文本主色，发送中转圈）。

### 4.5 ChatActionButtons（组件，85 行）

props：`showThink`、`language`、`showDocumentQuery` 三个 `Binding`。

三个胶囊按钮（`smallBtnHeight`，描边 `btnHeight/2` 圆角）：**深度思考**（toggle `showThink`，激活主色）、**查询文档**（toggle `showDocumentQuery`，激活主色）、**中文/英文**（`language = language == "zh" ? "en" : "zh"`，始终主色描边，文案随语言显示「中文/英文」）。

### 4.6 弹窗组件（本页以 overlay 方式挂载）

| 组件 | 关键 props / 回调 | 本页处理 |
|---|---|---|
| `TenantListPopup` | `isPresented: Binding<Bool>`、`onTenantSelected: (Tenant) -> Void` | 选中 → `handleTenantSelected` |
| `ModelListPopup` | `isPresented: Binding<Bool>`、`onModelSelected: (ChatModel) -> Void` | 选中 → `appState.saveCurrentModel(model)` 并关闭 |
| `DocumentPickerDialog` | `isPresented: Binding<Bool>`、`onConfirm: (Set<String>) -> Void` | 确认 → 写 `selectedDocIds`，非空则 `showDocumentQuery = true` |
| `ChatHistoryDialog` | `isPresented: Binding<Bool>`、`onSessionSelected: (String) -> Void` | 选中 → `loadChatHistory(chatId:)` |
| `UploadDocumentDialog` | `isPresented: Binding<Bool>`、`onUploadComplete: () -> Void` | 完成回调仅打印 |
| `MyDocumentsDialog` | `isPresented: Binding<Bool>` | 无额外回调 |
| `PromptDialog` | `isPresented: Binding<Bool>`、`onPromptUpdated: () -> Void` | 更新后 → `loadPrompt()`（**注意：该 overlay 未挂到 body，见 10.4**） |

### 4.7 menuActionSheet

`ActionSheet(title: Text("菜单"))`，按钮按顺序：

1. 「会话记录」→ `showChatHistory = true`
2. 「上传文档」→ `showUploadDocument = true`
3. 「我的文档」→ `showMyDocuments = true`
4. 「设置提示词」→ `showPromptDialog = true`
5. 「提示词管理」→ `showPromptManage = true`
6. 「模型管理」→ `showModelManage = true`，**仅当** `appState.currentCompany?.role ?? 0 > 0` 时追加（即当前公司在公司侧角色为 1/2 管理员才可见）
7. 「取消」（`.cancel`）

## 5. 核心方法

### `generateChatId()`
- **触发**：`onAppear`（当 `currentChatId` 为空时）、`clearAllMessages`
- **步骤**：`UUID().uuidString.replacingOccurrences(of: "-", with: "")` → 32 位无连字符 UUID。
- **说明**：chatId 是纯客户端生成，与后端 `chat_history.chat_id` 字段对应（`varchar(128)`）。

### `scrollToBottom(proxy:)`
- **触发**：`messages.count` 或 `messages.last?.content` 变化。
- **步骤**：取 `messages.last`，`withAnimation` 里 `proxy.scrollTo(lastMessage.id, anchor: .bottom)`。

### `clearAllMessages()`
- **触发**：输入栏「清空」按钮（`MessageInputBar.onClear`）。
- **步骤**：清空 `messages` → 重新生成 `currentChatId` → 清 `currentAIResponse`、`selectedDocIds`、`showDocumentQuery = false` → `webSocketManager.reset()`。

### `updateLastAIMessage(content:)`
- **触发**：流式收到消息时（两条路径，见 9.1）。
- **步骤**：`messages.lastIndex(where: { !$0.isUser })` 找到最后一条 AI 消息，**整体替换**为新的 `ChatMessage(content:isUser:false)`；找不到则追加一条。
- **注意**：每次替换都会生成新的 `ChatMessage`（`id = UUID()`），因此流式期间「最后一条 AI 消息」的身份不断变化（见 10.2）。

### `sendMessage()`
- **触发**：输入栏发送按钮。
- **步骤**：
  1. 校验输入非空（`trimmingCharacters`）、非 `isReceivingMessage`。
  2. 校验 `appState.currentModel`、`appState.currentTenant` 存在。
  3. 取公司 ID：`appState.currentCompany?.id ?? appState.getCachedCompanyId()`，两者都为空则终止并打印「未找到公司ID」。
  4. 追加用户消息 `ChatMessage(content:isUser:true)`，清空输入框。
  5. 追加空 AI 占位消息 `ChatMessage(content:"",isUser:false)`（由 `MessageBubble` 显示 loading）。
  6. 计算 `messageType`：`showDocumentQuery && !selectedDocIds.isEmpty` 时为 `"document"` 否则 `""`；`docIds` 同理为 `Array(selectedDocIds)` 或 `[]`。
  7. `webSocketManager.connect(...)` 发起连接，`onMessage` 内 `DispatchQueue.main.async` 累加 `currentAIResponse` 并 `updateLastAIMessage`；`onComplete` 内重置 `isReceivingMessage = false`、`currentAIResponse = ""`。
  8. `isReceivingMessage = true`。
- **失败处理**：所有 `guard` 失败仅 `print`，不弹任何用户提示。

### `loadTenantAndModel()`
- **触发**：`onAppear`。
- **步骤**：
  1. `isLoading = true`，新建 `DispatchGroup`。
  2. 取 `companyId`（`currentCompany?.id ?? getCachedCompanyId()`），为空则直接结束并打印错误。
  3. `group.enter` → `getTenantList(companyId:)`，回调主线程 `handleTenantListResult` 后 `leave`。
  4. `group.enter` → `getModelList(companyId:)`，回调主线程 `handleModelListResult` 后 `leave`。
  5. `group.notify(queue: .main)` → `isLoading = false`，再 `loadPrompt()`。
- **说明**：模型列表依赖公司 ID，租户列表也带上 `companyId`。

### `loadPrompt()`
- **触发**：`loadTenantAndModel` 完成后、切换租户后、`PromptDialog.onPromptUpdated`。
- **步骤**：
  1. 取 `appState.currentTenant?.id`，为空则打印警告返回。
  2. 从缓存取 `getCachedPromptId(tenantId:)`。
  3. `getPrompt(tenantId:promptId:)`，成功 → `appState.updatePrompt(prompt)`；失败 → `appState.currentPrompt = nil`。
- **说明**：`promptId` 为 nil 时后端返回该租户默认提示词（后端会自动创建）。

### `handleTenantListResult(_:)`
- 成功：`appState.tenantList = tenants`，再 `handleCurrentTenant(tenants)`；失败仅打印。

### `handleTenantSelected(_:)`
- `appState.saveCurrentTenant(tenant)` → 关弹窗 → `loadPrompt()`（切换租户后按新租户缓存重新加载提示词）。

### `handleCurrentTenant(_:)`
- 取 `getCachedTenantId()`：命中且列表中存在 → `appState.currentTenant = matchedTenant`；否则取 `tenants.first` → `saveCurrentTenant(firstTenant)`；命中后均 `loadPrompt()`。
- **边界**：列表为空时两个分支都不成立，`currentTenant` 保持 nil，也不会加载提示词。

### `handleModelListResult(_:)`
- 成功：`appState.modelList = models`，`handleCurrentModel(models)`；失败仅打印。

### `handleCurrentModel(_:)`
- 取 `getCachedModelId()`：命中且存在 → `currentModel = matchedModel`；否则取 `models.first` → `saveCurrentModel(firstModel)`。

### `loadChatHistory(chatId:)`
- **触发**：`ChatHistoryDialog.onSessionSelected`。
- **步骤**：
  1. `isLoading = true`。
  2. `guard let tenantId = appState.currentTenant?.id`，为空则结束（**但 tenantId 后续并未使用**，见 10.5）。
  3. `getChatHistoryByChatId(chatId:)`，成功 → 清空 `messages`、`currentChatId = chatId`、`convertHistoryToMessages(histories)`；失败仅打印。
  4. 结束 `isLoading = false`。

### `convertHistoryToMessages(_:)`
- **步骤**：
  1. 按 `createTime` 升序排序（`nil` 时间比较返回 `false`，排序不稳定）。
  2. 每条历史：先追加用户消息（`history.prompt`）；再拼 AI 内容：`thinkContent` 非空则包成 `<think>...</think>`，再拼 `responseContent`；两者都空用「暂无回复内容」；追加 AI 消息。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getTenantList` | GET | `/service/tenant/getTenantList` | `loadTenantAndModel` | `docs/api/tenant.md` |
| 2 | `getModelList` | GET | `/service/chat/getModelList` | `loadTenantAndModel` | `docs/api/chat.md` |
| 3 | `getPrompt` | GET | `/service/prompt/getPrompt` | `loadPrompt` | `docs/api/prompt.md` |
| 4 | `getChatHistoryByChatId` | GET | `/service/chat/getChatHistoryByChatId` | 选中历史会话 | `docs/api/chat.md` |
| 5 | （WebSocket）`WebSocketManager.connect` | WS | `/service/chat/ws/chat` | `sendMessage` | `docs/api/chat.md` |

> 弹窗组件内部额外调用：`getChatHistory`（ChatHistoryDialog）、`getDirectoryList` / `getDocListByDirId` / `createDirectory`（DocumentPickerDialog、UploadDocumentDialog、MyDocumentsDialog）、`uploadDoc` / `deleteDoc`、`updatePrompt`（PromptDialog）。

### 6.1 getTenantList

- **Swift 签名**：`func getTenantList(companyId: String? = nil, completion: @escaping (Result<[Tenant], NetworkError>) -> Void)`
- **APIEndpoint**：`.getTenantList`
- **请求**：Query `companyId`（本页必传，来自 `currentCompany?.id ?? getCachedCompanyId()`）
- **响应**：`BaseResponse<[Tenant]>.data`
- **UI 处理**：`appState.tenantList`，再按缓存回填 `currentTenant`。

### 6.2 getModelList

- **Swift 签名**：`func getModelList(companyId: String, keyword: String = "", completion: @escaping (Result<([ChatModel], Int), NetworkError>) -> Void)`
- **APIEndpoint**：`.getModelList(companyId)`（`companyId` 作为 query 参数注入 URL）
- **请求**：Query `companyId`（必填）、`keyword`（可选）
- **响应**：`BaseResponse<[ChatModel]>.data`，`total` 忽略（本页只取 `models`）
- **UI 处理**：`appState.modelList`，再按缓存回填 `currentModel`。

### 6.3 getPrompt

- **Swift 签名**：`func getPrompt(tenantId: String, promptId: String? = nil, completion: @escaping (Result<Prompt, NetworkError>) -> Void)`
- **APIEndpoint**：`.getPrompt`
- **请求**：Query `tenantId`（必填）、`promptId`（可选，本页取 `getCachedPromptId(tenantId:)`）
- **响应**：`BaseResponse<Prompt>.data`
- **UI 处理**：`appState.updatePrompt(prompt)`；失败置 `currentPrompt = nil`。

### 6.4 getChatHistoryByChatId

- **Swift 签名**：`func getChatHistoryByChatId(chatId: String, completion: @escaping (Result<[ChatHistory], NetworkError>) -> Void)`
- **APIEndpoint**：`.getChatHistoryByChatId`
- **请求**：Query `chatId`
- **响应**：`BaseResponse<[ChatHistory]>.data`（按时间正序）
- **UI 处理**：清空 `messages` → 设 `currentChatId` → `convertHistoryToMessages`。

### 6.5 WebSocket 聊天（WebSocketManager.connect）

- **Swift 签名**：

```swift
func connect(
    modelId: String,
    chatId: String,
    tenantId: String,
    companyId: String,
    prompt: String,
    showThink: Bool,
    language: String,
    docIds: [String] = [],
    type: String = "",
    onMessage: @escaping (String) -> Void,
    onComplete: @escaping () -> Void
)
```

- **连接地址**：`Constants.webSocketURL?token=Bearer <token>`（token 做 `urlQueryAllowed` 百分号编码）
- **发送体**（JSON）：`modelId`、`chatId`、`tenantId`、`companyId`、`type`、`docIds`、`prompt`、`systemPrompt`（取 `AppState.shared.currentPrompt?.prompt ?? ""`）、`showThink`、`language`
- **接收**：`receiveMessage()` 递归监听，`handleReceivedText` 里遇到 `[completed]` 或 `[done]` 标记即 `disconnect` 并 `onComplete`；否则 `currentResponse += text` 并 `onMessageReceived?(text)`。
- **结束/失败**：发送失败、序列化失败、接收失败均回 `onComplete`。

## 7. 数据模型

### 7.1 ChatMessage（`Models/ChatMessage.swift`）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `UUID`（`let id = UUID()`） | 每次构造即新值 |
| `content` | `String` | 消息内容 |
| `isUser` | `Bool` | true=用户，false=AI |
| `timestamp` | `Date` | `init` 里 `Date()` |

### 7.2 ChatHistory（`Models/ChatHistory.swift`）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `Int` | 否 | 主键 |
| `chatId` | `String` | 否 | 会话 ID |
| `prompt` | `String` | 否 | 用户消息 |
| `thinkContent` | `String?` | 是 | 思考内容 |
| `responseContent` | `String?` | 是 | AI 正文 |
| `createTime` / `updateTime` | `String?` | 是 | 时间 |
| `timeAgo` | `String`（默认 `""`） | — | 非数据库字段，`calculateTimeAgo()` 计算 |

另含 `getFullAIResponse()`（拼 `<think>` + 正文）与 `calculateTimeAgo()`。同文件还有 `ChatSessionGroup`（会话分组：`chatId`/`firstMessage`/`updateTime`/`timeAgo`）。

### 7.3 ChatModel（`Models/ChatModel.swift`）

本页用到的字段：`id`、`modelName`（标题栏显示）、`companyId`、`type`、`baseUrl`、`apiKey`（可选，`String?`）、`createTime`/`updateTime`。列表与发送都依赖 `id`。

### 7.4 Tenant（`Models/Tenant.swift`）

本页用到：`id`、`name`、`role`（当前用户在该租户的角色，0/1/2）。完整字段含 `code`、`description`、`status: TenantStatus`、`createDate`/`updateDate`、`createdBy`/`updatedBy` 等。

### 7.5 Prompt（`Models/Prompt.swift`）

`id`、`tenantId`、`userId`、`prompt`（内容）、`createTime`、`updateTime`。

### 7.6 Company（`Models/Company.swift`）

本页只用到 `id`、`name`、`role`（`Int?`，`role ?? 0 > 0` 判定管理员）。完整字段含 `code`、`description`、`status`、`createDate`/`updateDate`、`createdBy`/`updatedBy`，便捷属性 `isAdmin`/`isSuperAdmin`/`isNormalAdmin`。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor`（整页铺满，非卡片式） |
| 标题栏背景 | `Colors.whiteColor` |
| 消息气泡背景 | `Colors.whiteColor` + `Dimens.borderRadius` 圆角 |
| AI 思考块背景 | `Colors.grayColor.opacity(0.1)` |
| 气泡三角箭头 | `Colors.whiteColor`，12×12 |
| 加载中卡片 | `ProgressView`（`tint: Colors.subColor`）+ `Colors.whiteColor` |
| 按钮组描边 | `RoundedRectangle` 圆角 `Dimens.btnHeight / 2`，激活主色、未激活灰 |
| 输入栏 | `MessageInputBar` 白底，输入框 `Colors.pageBackgroundColor` 底 + `Dimens.inputHeight / 2` 圆角 |
| 图标色 | 菜单 `Colors.primaryColor`，清空/禁用 `Colors.grayColor` |
| 间距 | `Dimens.middleMargin` / `Dimens.smallIcon` |

## 9. 交互流程

### 9.1 发送消息（流式）

```
用户点发送 → sendMessage()
  → 校验输入/接收中/模型/租户/公司ID
  → messages += 用户消息 + 空 AI 占位（MessageBubble 显示 loading）
  → 计算 type/docIds（文档问答）
  → WebSocketManager.connect(…)
       ├─ sendMessage(JSON 含 systemPrompt=currentPrompt.prompt)
       └─ receiveMessage() 递归
            └─ handleReceivedText: currentResponse += text; onMessage(text)
                 → HomePage.onMessage: currentAIResponse += text; updateLastAIMessage(full)
                 → HomePage.onReceive($currentResponse): currentAIResponse = newResponse; updateLastAIMessage(full)   ← 冗余第二路
            └─ 遇到 [completed]/[done] → disconnect + onComplete
                 → isReceivingMessage = false; currentAIResponse = ""
```

**注意**：流式更新有两条并行的写回路径（`onMessage` 闭包 + `onReceive($currentResponse)`），两者最终都把「累计全文」写进最后一条 AI 消息，结果一致但重复写（见 10.2）。

### 9.2 页面初始化

```
onAppear → loadTenantAndModel()
  → 取 companyId（内存 or 缓存），为空即中止
  → DispatchGroup 并发拉 getTenantList + getModelList
  → notify → isLoading=false → loadPrompt()（按 tenantId 缓存回填）
onAppear 同时：currentChatId 为空 → generateChatId()
```

### 9.3 切换租户

```
点标题栏租户名 → showTenantList=true → TenantListPopup
  → 选中 → handleTenantSelected(tenant)
      → saveCurrentTenant(tenant)（写 current_tenant_id 缓存）
      → loadPrompt()（按新 tenantId 缓存取 promptId）
```

### 9.4 切换模型

```
点标题栏模型名 → showModelList=true → ModelListPopup
  → 选中 → appState.saveCurrentModel(model)（写 current_model_id 缓存）+ 关弹窗
```

### 9.5 文档问答

```
点「查询文档」→ showDocumentQuery=true → 输入栏出现文档选择按钮
  → 点按钮 → DocumentPickerDialog（目录 → 文档多选）
      → onConfirm(selectedIds) → selectedDocIds；非空则 showDocumentQuery 保持 true
发送时：showDocumentQuery && !selectedDocIds.isEmpty
  → type="document", docIds=[…] 进入 WS 消息体
```

### 9.6 会话历史

```
菜单「会话记录」→ ChatHistoryDialog（getChatHistory 分页，按 chatId 分组倒序）
  → 选中 session.chatId → loadChatHistory(chatId)
      → getChatHistoryByChatId → convertHistoryToMessages（正序回填 + <think> 包裹思考）
```

## 10. 二次开发指引

- **改文案/样式**：标题栏 → `ChatHeader`；消息气泡/思考块/loading → `MessageBubble`/`MessageContentView`；操作按钮 → `ChatActionButtons`；输入栏 → `MessageInputBar`。
- **加字段**（如新增发送参数）：`WebSocketManager.sendMessage` 的字典 + `connect` 签名 + `HomePage` state + `ChatActionButtons`/`MessageInputBar` props 需同步改。
- **加接口**：`Constants.API` → `APIEndpoint`（path + method）→ `HTTPClient` 方法 → `HomePage` 调用。
- **改菜单**：定位 `menuActionSheet`，注意「模型管理」的权限门槛在 `appState.currentCompany?.role ?? 0 > 0`。

### 10.1 已知坑

1. **`PromptDialog` 未挂载**：`promptDialogOverlay`（第 574 行的 `@ViewBuilder private var`）从未出现在 `body` 的 overlay 链里。菜单点「设置提示词」只会把 `showPromptDialog` 置 `true`，但对话框不会显示——是个失效入口。
2. **流式更新双重写回 + 整条替换**：`sendMessage` 里 `connect` 的 `onMessage` 闭包和 `body` 的 `.onReceive($currentResponse)` 都会调用 `updateLastAIMessage`，且都用「累计全文」覆盖；同时 `updateLastAIMessage` 每次都 `ChatMessage(...)` 新建（`id = UUID()` 变化），流式期间最后一条 AI 消息身份不断变化，滚动锚点 `scrollToBottom` 依赖 `last.id`。
3. **`updatePrompt`（HTTPClient）丢弃 prompt 内容**：`HTTPClient.updatePrompt(prompt:)` 只序列化 `id`/`tenantId`/`userId`，**不含 `prompt` 字段**；`PromptDialog` 用此方法保存，导致用户编辑的提示词内容实际不会发送到后端（正确实现应参考同文件 `updatePromptById(id:prompt:tenantId:)`，它带 `prompt`）。
4. **`getChatHistoryByChatId` 不算 `timeAgo`**：只有 `getChatHistory` 会对列表逐条调用 `calculateTimeAgo()`，`getChatHistoryByChatId` 不调（历史回填场景未用到 `timeAgo`，暂无影响）。
5. **`loadChatHistory` 的 tenantId 校验形同虚设**：`guard let tenantId = currentTenant?.id` 后 `tenantId` 并未使用，但当前租户为空会拦截历史加载。
6. **`handleCurrentTenant` 空列表无兜底**：租户列表为空时 `currentTenant` 保持 nil 且不加载提示词，页面顶部显示「选择租户」但无任何提示。
7. **公司 ID 缺失静默失败**：`sendMessage`/`loadTenantAndModel` 取不到 `companyId` 时只 `print`，用户无感知。

## 相关文档

- [CompanyPage](CompanyPage.md)（入口页）
- 后端接口：`docs/api/chat.md`、`docs/api/tenant.md`、`docs/api/prompt.md`
