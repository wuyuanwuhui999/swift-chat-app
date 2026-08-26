---
name: update-model-page
description: 更新模型页（UpdateModelPage）。回填已有 ChatModel 并调用 updateModel 提交修改；需要改模型编辑表单、回填逻辑或 API Key 清空问题时读这份文档。
page: UpdateModelPage.swift
path: chat/chat/UI/Pages/UpdateModelPage.swift
apis:
  - PUT /service/chat/updateModel
---

# UpdateModelPage（更新模型页）

## 1. 页面职责

`UpdateModelPage` 是 [AddModelPage](AddModelPage.md) 的编辑版：构造时接收一个完整的 `ChatModel`，在 `onAppear` 把它回填进四个表单字段（名称 / 类型 / 地址 / API Key），用户修改后带上 `model.id` 调用 `PUT /service/chat/updateModel`。

只能从 [ModelManagePage](ModelManagePage.md) 的列表行左滑「编辑」进入。成功后通过 `onModelUpdated` 回调让父页面重新拉取列表，再 `dismiss()` 返回。视图结构与 `AddModelPage` 几乎逐行一致，差异只有：标题文案、`model` 构造参数、`loadModelData()`、提交方法。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/UpdateModelPage.swift`（约 322 行）
- **入口**：`ModelManagePage` 的 `navigationDestination(isPresented: $navigateToUpdatePage)`，构造为
  `UpdateModelPage(model: model, onModelUpdated: { loadModelList(reset: true) })`（`model` 来自 `@State selectedModel`）
- **出口**：仅 `dismiss()` 返回 `ModelManagePage`
- **依赖组件**：无外部组件；同文件内私有 `formRow(label:isRequired:content:)`、`DividerLine()`
- **依赖模型**：`ChatModel`（构造入参）、`ChatModelType`（`Models/ChatModelType.swift`，类型枚举与中文文案）
- **依赖服务**：`HTTPClient.shared.updateModel`、`AppState.shared`（`currentCompany` / `getCachedCompanyId()`）、`Utils/Validators.swift`、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 取 `currentCompany?.id`，兜底 `getCachedCompanyId()` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 返回上一页 |
| `model` | `ChatModel`（`let`，构造参数） | — | 待编辑的模型，提供 `id` 与回填数据 |
| `onModelUpdated` | `(() -> Void)?`（`let`，构造参数） | `nil` | 更新成功后通知父页面刷新 |
| `modelName` | `String`（`@State`） | `""` → `onAppear` 回填 | 模型名称（必填） |
| `modelType` | `String`（`@State`） | `ChatModelType.ollama.rawValue` → `onAppear` 回填 | 模型类型（Picker，存原始值） |
| `baseUrl` | `String`（`@State`） | `""` → `onAppear` 回填 | 模型地址（必填） |
| `apiKey` | `String`（`@State`） | `""` → `onAppear` 回填 | API Key（在线模型必填） |
| `isSubmitting` | `Bool`（`@State`） | `false` | 提交中（按钮转圈并禁用） |
| `showAlert` | `Bool`（`@State`） | `false` | 提示弹窗开关 |
| `alertMessage` | `String`（`@State`） | `""` | 提示内容 |
| `shouldDismiss` | `Bool`（`@State`） | `false` | 标记「弹窗确认后回调 + 关页」 |
| `modelTypes` / 中文文案 | 由 `ChatModelType` 提供 | 枚举 `ollama` / `online`；`displayName` 给 Picker、`rawValue` 提交后端 |

计算属性 / 辅助方法（与 [AddModelPage](AddModelPage.md) 完全一致）：

| 名称 | 实现 | 含义 |
|---|---|---|
| `isApiKeyRequired` | `ChatModelType.requiresApiKey(for: modelType)` | 在线模型必须填 API Key |
| `Validators.isValidBaseUrl(_:)` | `scheme` 为 `http`/`https` 且 `host` 非空 | 模型地址格式校验（提交时执行，两页共用） |
| `isFormValid` | `modelName`、`baseUrl` trim 后非空；且 `isApiKeyRequired` 时 `apiKey` 非空 | 控制「确定」按钮可点状态 |

构造函数：`init(model: ChatModel, onModelUpdated: (() -> Void)? = nil)`。

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar        whiteColor 底 / 上下左右 middleMargin / 底部 1px grayColor.opacity(0.3)
│   ├─ 返回 chevron.left（Colors.subColor，middleIcon）→ dismiss()
│   ├─ 标题「更新模型」（middleFont / .black）
│   └─ Color.clear 占位（middleIcon × middleIcon）
└─ ScrollView（背景 pageBackgroundColor）
   └─ VStack(spacing: middleMargin)，四周 middleMargin 内边距
      ├─ formCardView          whiteColor + borderRadius，VStack(spacing: 0)
      │   ├─ formRow「模型名称」必填 → TextField(prompt:「请输入模型名称」)
      │   ├─ DividerLine()
      │   ├─ formRow「模型类型」必填 → Picker(MenuPickerStyle, tint .black) ForEach(ChatModelType.allCases)
      │   │      展示 type.displayName（「ollama模型」/「在线模型」），tag 用 type.rawValue
      │   ├─ DividerLine()
      │   ├─ formRow「模型地址」必填 → TextField(prompt:「请输入模型地址」) .autocapitalization(.none)
      │   ├─ DividerLine()
      │   └─ formRow「API Key」isRequired: isApiKeyRequired（在线模型显示红 `*`）
      │          → TextField(prompt: isApiKeyRequired ?「请输入API Key」:「请输入API Key（可选）」) .autocapitalization(.none)
      └─ actionButtonsView
          ├─ 「取消」透明底 + grayColor 描边/文字 → dismiss()
          └─ 「确定」isFormValid ? primaryColor : grayColor；提交中显示 ProgressView
                .disabled(!isFormValid || isSubmitting)
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) { if shouldDismiss { dismiss() } } }   ← 只关页；刷新已在请求成功时触发
├─ .navigationBarHidden(true)
└─ .onAppear { loadModelData() }
```

`formRow` / `DividerLine` 与 `AddModelPage` 实现完全一致：label 区固定 `width: 80`、必填前置 `Colors.warnColor` 星号；分隔线 1px `grayColor.opacity(0.3)` 且左缩进 `middleMargin`。

## 5. 核心方法

### `loadModelData()`
- **触发**：`.onAppear`
- **步骤**：
  1. `modelName = model.modelName`
  2. `modelType = model.type`
  3. `baseUrl = model.baseUrl`
  4. `apiKey = model.apiKey ?? ""`
- **注意**：无条件覆盖四个 `@State`；只要 `onAppear` 再次触发（例如从本页 push 出别的页面再返回），用户未提交的编辑会被重置成原值（见 10.1）。若 `model.type` 不是 `ChatModelType` 的取值（如后端历史数据 `deepseek`），Picker 会处于「无匹配选项」状态（见 10.1）。
- **注意**：`model.disabled` 不进表单，只在提交时原样回传，避免编辑名称/地址时把禁用状态改掉。

### `handleUpdateModel()`
- **触发**：「确定」按钮点击（`Button(action: handleUpdateModel)`）
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { alertMessage = "未找到公司ID"; showAlert = true; return }`
  2. `modelName` / `baseUrl` / `apiKey` 各自 `trimmingCharacters(in: .whitespacesAndNewlines)`
  3. `guard Validators.isValidBaseUrl(trimmedUrl)`，否则 alert「模型地址格式不正确，需以 http:// 或 https:// 开头」并 return（必填项由 `isFormValid` 拦在按钮上，此处只补格式校验）
  4. `isSubmitting = true`
  5. 调 `HTTPClient.shared.updateModel(modelId: model.id, modelName:type:companyId:apiKey:baseUrl:disabled:)`，`apiKey` 传 `trimmedApiKey.isEmpty ? nil : trimmedApiKey`，`disabled` 传 `model.disabled`（nil 时该字段不提交）
  6. 回调 `DispatchQueue.main.async`，先 `isSubmitting = false`
     - 成功且 `data > 0` → **先 `onModelUpdated?()` 通知父页刷新**，再 `alertMessage = "更新成功"`、`shouldDismiss = true`、`showAlert = true`
     - 成功但 `data <= 0` → `alertMessage = "更新失败，请稍后重试"`、`showAlert = true`
     - 失败 → `alertMessage = error.localizedDescription`、`showAlert = true`
- **失败处理**：统一走 `alert`；`shouldDismiss == true` 时点「确定」只做 `dismiss()`（刷新与弹窗解耦）。
- **注意**：`companyId` 用的是**当前公司**，不是 `model.companyId`；理论上二者相同，但跨公司场景下会把模型改到当前公司名下（见 10.1）。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `updateModel` | PUT | `/service/chat/updateModel` | 点击「确定」 | `docs/api/chat.md` |

### 6.1 `updateModel`

- **Swift 签名**：
  ```swift
  func updateModel(
      modelId: String,
      modelName: String,
      type: String,
      companyId: String,
      apiKey: String?,
      baseUrl: String,
      disabled: Int? = nil,
      completion: @escaping (Result<Int, NetworkError>) -> Void
  )
  ```
- **APIEndpoint**：`.updateModel`（`path` = `Constants.API.updateModel` = `/service/chat/updateModel`；`method` = `"PUT"`，与 `.updateUser`、`.updatePrompt` 同一分支）
- **请求**：PUT → 非 GET/DELETE，`parameters` 序列化为 JSON Body

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `id` | Body | String | 是 | **注意 key 是 `id`**，值来自 `modelId`（即 `model.id`） |
| `modelName` | Body | String | 是 | 模型名称 |
| `type` | Body | String | 是 | 取值只有 `ollama` / `online`（`ChatModelType`，后端文档未更新） |
| `companyId` | Body | String | 是 | 取当前公司，非 `model.companyId` |
| `baseUrl` | Body | String | 是 | 模型 API 地址 |
| `disabled` | Body | Int | 否 | 原样回传 `model.disabled`（0 启用 / 1 禁用）；为 nil 时不提交该字段，避免覆盖后端状态 |
| `apiKey` | Body | String | 条件必填 | 在线模型（`type == "online"`）必填；仅当非 nil 且非空才写入 `parameters` |

- **响应**：`BaseResponse<Int>`；`HTTPClient` 要求 `isSuccess && data != nil` 才 `.success(data)`，否则 `.failure(.custom(message: response.msg ?? "更新模型失败"))`。后端文档「更新模型」出参示例为 `"data": null`（见 10.1）。
- **后端字段对照**：`chat.md` 的 `AddModelSchema / UpdateModelSchema` 字段表为 `type` / `apiKey` / `modelName` / `baseUrl` / `disabled` / `companyId`，**没有列出 `id`**。客户端提交的 `id` 属于「后端文档未覆盖，按客户端实现推断」（更新必须要主键，实际后端应支持）。
- **权限**：后端标注「更新模型（需企业管理员权限）」。
- **UI 处理**：见 `handleUpdateModel`。

## 7. 数据模型

### 7.1 ChatModel（`Models/ChatModel.swift`）—— 本页构造入参

| 字段 | 类型 | 可选 | 本页用途 |
|---|---|---|---|
| `id` | `String` | 否 | 提交时作为 Body 的 `id` |
| `modelName` | `String` | 否 | 回填「模型名称」 |
| `type` | `String` | 否 | 回填 Picker（注释：ollama 或 online） |
| `baseUrl` | `String` | 否 | 回填「模型地址」 |
| `apiKey` | `String?` | 是 | 回填「API Key」（nil → `""`） |
| `companyId` | `String` | 否 | **未使用**（提交用当前公司 ID） |
| `disabled` | `Int?` | 是 | 不进表单，提交时原样回传（0 启用 / 1 禁用） |
| `updateTime` / `createTime` | `String?` | 是 | 未使用 |

`#Preview` 里用硬编码的 `ChatModel(id: "1", modelName: "DeepSeek-R1", type: "online", baseUrl: "https://api.deepseek.com/v1", apiKey: ..., companyId: "company1", disabled: 0, updateTime: ..., createTime: ...)` 构造预览。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏 | `Colors.whiteColor` 底 + 底部 1px `Colors.grayColor.opacity(0.3)` |
| 返回图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题「更新模型」 | `Dimens.middleFont`，`.black` |
| 表单卡片 | `Colors.whiteColor` + `Dimens.borderRadius`，行内边距 `Dimens.middleMargin` |
| 必填星号 | `Colors.warnColor` |
| label 宽度 | 写死 `80` |
| 输入文字 / 占位 | `Dimens.normalFont`，`.black` / `Colors.grayColor` |
| 行分隔线 | 1px `Colors.grayColor.opacity(0.3)`，左缩进 `Dimens.middleMargin` |
| 取消按钮 | 透明底 + `Colors.grayColor` 描边与文字，高 `Dimens.btnHeight`，圆角 `btnHeight / 2` |
| 确定按钮 | 有效 `Colors.primaryColor` / 无效 `Colors.grayColor`，白字，圆角 `btnHeight / 2` |

## 9. 交互流程

```
ModelManagePage 列表行左滑 →「编辑」
  → resetOffset() → selectedModel = model; navigateToUpdatePage = true
  → navigationDestination { if let model = selectedModel { UpdateModelPage(model:onModelUpdated:) } }
  → onAppear → loadModelData() 回填四个字段
  → 用户修改 → isFormValid 联动「确定」按钮颜色与 disabled
     类型切到「在线模型」→ API Key 行出现红 `*`，占位文案变「请输入API Key」，未填时按钮不可点
  → 点「确定」→ handleUpdateModel
       ├─ 无 companyId → alert「未找到公司ID」，留在本页
       ├─ 地址不合法 → alert「模型地址格式不正确，需以 http:// 或 https:// 开头」→ 留在本页
       └─ 校验通过 → isSubmitting = true
             → PUT /service/chat/updateModel  Body { id, modelName, type, companyId, baseUrl[, disabled][, apiKey] }
             ├─ data > 0 → 立即 onModelUpdated?()（父页 loadModelList(reset: true)）
             │     → alert「更新成功」+ shouldDismiss = true → 点「确定」→ dismiss()
             ├─ data <= 0 → alert「更新失败，请稍后重试」，留在本页
             └─ .failure → alert(error.localizedDescription)，留在本页
「取消」→ dismiss()（不回调，父页面列表不刷新）
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；表单 `formCardView` + `formRow`；按钮 `actionButtonsView`。
- **加字段**：`ChatModel` → `loadModelData()` 回填 → `formCardView` 加 `formRow` → `isFormValid`（若必填）→ `HTTPClient.updateModel` 形参与 `parameters` → 后端 `UpdateModelSchema`；并同步 [AddModelPage](AddModelPage.md)。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method`）→ `HTTPClient` → 页面。
- **改模型类型选项**：只改 `Models/ChatModelType.swift`（case + `displayName` + `requiresApiKey`），本页与 [AddModelPage](AddModelPage.md) 同时生效。
- **改地址校验规则**：只改 `Utils/Validators.swift` 的 `isValidBaseUrl(_:)`，两页共用。
- **想复用表单**：本页与 `AddModelPage` 的 `formCardView` / `formRow` / `DividerLine` / `actionButtonsView` / `isFormValid` 是**逐行复制**的两份实现，建议抽到 `UI/Components/` 下的公共 `ModelFormView`，否则改样式必须改两处。

### 10.1 已知坑

1. **API Key 无法清空**：`handleUpdateModel` 里 `apiKey` 为空时传 `nil`，`HTTPClient.updateModel` 内 `if let apiKey = apiKey, !apiKey.isEmpty` 才写入 `parameters`。也就是说「把 API Key 删空再保存」不会向后端提交 `apiKey` 字段，后端大概率保留旧值 —— 从 `online` 改回 `ollama` 时无法清掉凭证。建议明确传空字符串或增加 `clearApiKey` 语义。
2. **`onAppear` 无条件覆盖用户输入**：`loadModelData()` 没有「只回填一次」的判断，页面重新出现即重置未提交的修改。建议加 `@State private var didLoad` 之类的守卫。
3. **`model.type` 可能不在 `ChatModelType` 里**：Picker 选项只有 `ollama` / `online`，若回填一个后端历史数据（如 `deepseek`），Picker 没有匹配 tag，显示异常，用户一动就会把 type 改成 `ollama` 或 `online`。
4. **提交的 `companyId` 不是模型自己的 `companyId`**：用的是 `appState.currentCompany?.id ?? getCachedCompanyId()`，忽略了入参 `model.companyId`。正常路径下两者相同，但若公司状态与列表数据不同步，会把模型归属改到当前公司。建议直接用 `model.companyId`。
5. **更新接口的 `data` 语义未确认**：客户端要求 `data` 非 nil 且 `> 0`；后端文档「更新模型」示例为 `"data": null`。新增接口已确认实际返回 `1`（见 [AddModelPage](AddModelPage.md) §6.1），更新接口尚未确认，若真返回 null 会走 `.failure` 提示"更新模型失败"但数据已改。
6. **后端 Schema 未列 `id`**：`chat.md` 的 `UpdateModelSchema` 字段表只有 type/apiKey/modelName/baseUrl/disabled/companyId，客户端额外提交 `id`；文档需要补齐，否则后续联调容易误删该字段。
7. **本页不能改启用状态**：`disabled` 只做原样回传，没有开关 UI；启用/禁用模型目前无入口（后端字段支持）。
8. **「取消」不刷新父页**：`dismiss()` 不触发 `onModelUpdated`，而父页 `.onAppear` 挂在 `NavigationStack` 外层不会重跑，因此取消返回后列表仍是旧数据（正常，但要知道刷新完全依赖回调）。
9. **`selectedModel` 不复位**：父页 `navigateToUpdatePage` 关闭后 `selectedModel` 仍保留上一次的模型；下一次点「编辑」是先赋值再置 true，才保证正确，改动这段顺序容易引入「编辑到上一个模型」的 bug。

## 相关文档

- [ModelManagePage](ModelManagePage.md)（父页面）
- [AddModelPage](AddModelPage.md)（同构的新增页）
- 后端接口：`docs/api/chat.md`
