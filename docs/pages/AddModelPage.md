---
name: add-model-page
description: 新增模型页（AddModelPage）。表单录入模型名称/类型/地址/API Key 并调用 addModel 新增公司模型；需要改模型表单校验、类型枚举或提交流程时读这份文档。
page: AddModelPage.swift
path: chat/chat/UI/Pages/AddModelPage.swift
apis:
  - POST /service/chat/addModel
---

# AddModelPage（添加模型页）

## 1. 页面职责

`AddModelPage` 是一个纯表单页：录入「模型名称、模型类型、模型地址、API Key」四个字段，提交给 `/service/chat/addModel`，为当前公司新增一条大模型配置。

它只能从 [ModelManagePage](ModelManagePage.md) 的导航栏「+」进入，成功后通过构造时传入的 `onModelAdded` 回调通知父页面刷新列表，然后 `dismiss()` 返回。页面本身不查任何数据，`companyId` 完全取自 `AppState`。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/AddModelPage.swift`（约 352 行）
- **入口**：`ModelManagePage` 的 `navigationDestination(isPresented: $showAddModelPage)`，构造为 `AddModelPage(onModelAdded: { loadModelList(reset: true) })`
- **出口**：仅 `dismiss()` 返回 `ModelManagePage`
- **依赖组件**：无外部组件；同文件内私有 `formRow(label:isRequired:content:)` 与 `DividerLine()`
- **依赖模型**：无（不解析 `ChatModel`，成功返回值是 `Int`）
- **依赖服务**：`HTTPClient.shared.addModel`、`AppState.shared`（`currentCompany` / `getCachedCompanyId()`）、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 取 `currentCompany?.id`，兜底 `getCachedCompanyId()` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 返回上一页 |
| `onModelAdded` | `(() -> Void)?`（`let`，构造参数） | `nil` | 新增成功后通知父页面刷新 |
| `modelName` | `String`（`@State`） | `""` | 模型名称（必填） |
| `modelType` | `String`（`@State`） | `"ollama"` | 模型类型（必填，Picker 选择） |
| `baseUrl` | `String`（`@State`） | `""` | 模型地址（必填） |
| `apiKey` | `String`（`@State`） | `""` | API Key（可选） |
| `isSubmitting` | `Bool`（`@State`） | `false` | 提交中（按钮显示 `ProgressView` 并禁用） |
| `showAlert` | `Bool`（`@State`） | `false` | 提示弹窗开关 |
| `alertMessage` | `String`（`@State`） | `""` | 提示内容 |
| `shouldDismiss` | `Bool`（`@State`） | `false` | 标记「弹窗确认后要回调 + 关页」 |
| `modelTypes` | `[String]`（`private let`） | `["ollama", "online"]` | Picker 选项（提交给后端的原始值） |
| `modelTypeNames` | `[String: String]`（`private let`） | `["ollama": "ollama模型", "online": "在线模型"]` | 类型 → 中文展示映射，Picker 只显示中文 |

计算属性 / 辅助方法：

| 名称 | 实现 | 含义 |
|---|---|---|
| `isApiKeyRequired` | `modelType == "online"` | 在线模型必须填 API Key（`ollama` 本地模型不需要凭证） |
| `displayName(for:)` | `modelTypeNames[type] ?? type` | 取类型的中文展示文案，无映射回退原始值 |
| `isValidBaseUrl(_:)` | `URL(string:)` 可解析、`scheme` 为 `http`/`https`、`host` 非空 | 模型地址格式校验（提交时执行） |
| `isFormValid` | `modelName`、`baseUrl` 去空白后非空；且 `isApiKeyRequired` 时 `apiKey` 非空 | 控制「确定」按钮可点状态 |

构造函数：`init(onModelAdded: (() -> Void)? = nil)`，支持不传回调（`#Preview` 就是 `AddModelPage()`）。

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar        whiteColor 底 / 上下左右 middleMargin / 底部 1px grayColor.opacity(0.3)
│   ├─ 返回 chevron.left（Colors.subColor，middleIcon）→ dismiss()
│   ├─ 标题「添加模型」（middleFont / .black）
│   └─ Color.clear 占位（middleIcon × middleIcon）
└─ ScrollView（背景 pageBackgroundColor）
   └─ VStack(spacing: middleMargin)，四周 middleMargin 内边距
      ├─ formCardView          whiteColor + borderRadius 圆角，内部 VStack(spacing: 0)
      │   ├─ formRow「模型名称」必填 → TextField(prompt:「请输入模型名称」grayColor)
      │   ├─ DividerLine()
      │   ├─ formRow「模型类型」必填 → Picker(MenuPickerStyle, .tint(.black)) ForEach(modelTypes)
      │   │      展示 displayName(for:)（ollama→「ollama模型」/ online→「在线模型」），tag 仍是原始值
      │   ├─ DividerLine()
      │   ├─ formRow「模型地址」必填 → TextField(prompt:「请输入模型地址」) .autocapitalization(.none)
      │   ├─ DividerLine()
      │   └─ formRow「API Key」isRequired: isApiKeyRequired（在线模型显示红 `*`）
      │          → TextField(prompt: isApiKeyRequired ?「请输入API Key」:「请输入API Key（可选）」) .autocapitalization(.none)
      └─ actionButtonsView     HStack(spacing: middleMargin)
          ├─ 「取消」透明底 + grayColor 描边/文字，高 btnHeight，圆角 btnHeight/2 → dismiss()
          └─ 「确定」isFormValid ? primaryColor : grayColor，白字，圆角 btnHeight/2
                提交中显示白色 ProgressView；.disabled(!isFormValid || isSubmitting)
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) { if shouldDismiss { dismiss() } } }   ← 只关页；刷新已在请求成功时触发
└─ .navigationBarHidden(true)
```

### 4.1 `formRow(label:isRequired:content:)`

`HStack(alignment: .center, spacing: middleMargin)`：左侧 label 区固定 `width: 80`、左对齐，必填时前置红色 `*`（`Colors.warnColor`）；右侧 `content`（`AnyView`）`maxWidth: .infinity` 左对齐。整行左右/上下 `middleMargin` 内边距。

### 4.2 `DividerLine()`

1px `Colors.grayColor.opacity(0.3)` 矩形，`padding(.leading, Dimens.middleMargin)`（左侧缩进，与 label 对齐）。

## 5. 核心方法

### `handleAddModel()`
- **触发**：「确定」按钮点击（`Button(action: handleAddModel)`）
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { alertMessage = "未找到公司ID"; showAlert = true; return }`
  2. 对 `modelName` / `baseUrl` / `apiKey` 分别 `trimmingCharacters(in: .whitespacesAndNewlines)`
  3. `guard isValidBaseUrl(trimmedUrl)`，否则 alert「模型地址格式不正确，需以 http:// 或 https:// 开头」并 return（必填项由 `isFormValid` 拦在按钮上，此处只补格式校验）
  4. `isSubmitting = true`
  5. 调 `HTTPClient.shared.addModel(modelName:type:companyId:apiKey:baseUrl:disabled:)`，`apiKey` 传 `trimmedApiKey.isEmpty ? nil : trimmedApiKey`，`disabled` 固定传 `0`（启用）
  6. 回调内 `DispatchQueue.main.async`：先 `isSubmitting = false`
     - 成功且 `data > 0` → **先 `onModelAdded?()` 通知父页刷新**，再 `alertMessage = "添加成功"`、`shouldDismiss = true`、`showAlert = true`
     - 成功但 `data <= 0` → `alertMessage = "添加失败，请稍后重试"`、`showAlert = true`（`shouldDismiss` 保持 false）
     - 失败 → `alertMessage = error.localizedDescription`、`showAlert = true`
- **失败处理**：全部通过同一个 `alert` 展示；`shouldDismiss == true` 时点「确定」只做 `dismiss()`（刷新与弹窗解耦），失败时留在表单页保留已填内容。
- **校验分工**：必填（含在线模型的 API Key）→ `isFormValid` 控制按钮可点；格式（模型地址）→ 提交时校验并弹提示，避免按钮被"神秘禁用"。

### `isValidBaseUrl(_ urlString: String) -> Bool`
- **触发**：`handleAddModel` 第 3 步
- **实现**：`URL(string:)` 能解析，且 `scheme` 小写后为 `http`/`https`，且 `host` 非空；任一不满足返回 `false`。

### `displayName(for type: String) -> String`
- **触发**：模型类型 Picker 渲染每个选项
- **实现**：`modelTypeNames[type] ?? type`，即 `ollama` → 「ollama模型」、`online` → 「在线模型」，未配置映射时回退原始值。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `addModel` | POST | `/service/chat/addModel` | 点击「确定」 | `docs/api/chat.md` |

### 6.1 `addModel`

- **Swift 签名**：
  ```swift
  func addModel(
      modelName: String,
      type: String,
      companyId: String,
      apiKey: String?,
      baseUrl: String,
      disabled: Int = 0,
      completion: @escaping (Result<Int, NetworkError>) -> Void
  )
  ```
- **APIEndpoint**：`.addModel`（`path` = `Constants.API.addModel` = `/service/chat/addModel`；`method` = `"POST"`，与 `.insertPrompt` 等归在同一 POST 分支）
- **请求**：POST → `HTTPClient.request` 把 `parameters` 序列化成 JSON Body（`Content-Type: application/json`）

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `modelName` | Body | String | 是 | 模型名称 |
| `type` | Body | String | 是 | 取值只有 `ollama` / `online`（客户端口径，后端文档未更新） |
| `companyId` | Body | String | 是 | 来自 `currentCompany?.id ?? getCachedCompanyId()` |
| `baseUrl` | Body | String | 是 | 模型 API 基础路径，需 `http://` / `https://` 开头 |
| `disabled` | Body | Int | 是 | 启用状态 0 启用 / 1 禁用；本页固定传 `0`，不再依赖后端默认值 |
| `apiKey` | Body | String | 条件必填 | 在线模型（`type == "online"`）必填；仅当非 nil 且非空才写入 `parameters` |

- **响应**：`BaseResponse<Int>`，**添加成功后端返回 `data = 1`**（后端文档 `chat.md`「新增模型」出参示例写 `data: null` 是文档未更新）。`HTTPClient` 要求 `isSuccess && data != nil` 才回调 `.success(data)`，否则 `.failure(.custom(message: response.msg ?? "添加模型失败"))`；页面再按 `data > 0` 判成功。
- **后端字段对照**（`chat.md` → `AddModelSchema / UpdateModelSchema`）：`type` / `apiKey` / `modelName` / `baseUrl` / `disabled` / `companyId`，客户端现已全部提交（`disabled` 固定 0）。
- **权限**：后端标注「添加模型（需企业管理员权限）」，客户端侧的权限控制体现在 `HomePage` 只对管理员显示「模型管理」入口。
- **UI 处理**：见 `handleAddModel`。

## 7. 数据模型

本页不直接使用 `ChatModel`（只提交字段、只解析 `Int`），但字段语义与 `Models/ChatModel.swift` 一一对应：

| 表单字段 | ChatModel 字段 | 类型 | 说明 |
|---|---|---|---|
| 模型名称 | `modelName` | `String` | 必填 |
| 模型类型 | `type` | `String` | 只有 `ollama` / `online`；UI 展示中文（ollama模型 / 在线模型） |
| 模型地址 | `baseUrl` | `String` | 必填，需 `http(s)://` 开头 |
| API Key | `apiKey` | `String?` | 在线模型必填；为空时不提交该字段 |
| （隐式） | `companyId` | `String` | 取自全局状态 |
| （隐式） | `disabled` | `Int` | 新增固定提交 `0`（启用） |

后端表 `chat_model` 相关列：`model_name`、`type`、`base_url`、`api_key`、`company_id`、`disabled`、`create_time`（返回时由 `ResultUtil` 转驼峰）。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏 | `Colors.whiteColor` 底 + 底部 1px `Colors.grayColor.opacity(0.3)` |
| 返回图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont`，`.black` |
| 表单卡片 | `Colors.whiteColor` + `Dimens.borderRadius`，行内边距 `Dimens.middleMargin` |
| 必填星号 | `Colors.warnColor` |
| label 宽度 | 写死 `80` |
| 输入文字 / 占位 | `Dimens.normalFont`，`.black` / `Colors.grayColor` |
| 行分隔线 | 1px `Colors.grayColor.opacity(0.3)`，左缩进 `Dimens.middleMargin` |
| 取消按钮 | 透明底 + `Colors.grayColor` 描边与文字，高 `Dimens.btnHeight`，圆角 `btnHeight / 2` |
| 确定按钮 | 有效 `Colors.primaryColor` / 无效 `Colors.grayColor`，白字，高 `Dimens.btnHeight`，圆角 `btnHeight / 2` |

## 9. 交互流程

```
ModelManagePage 导航栏「+」→ showAddModelPage = true
  → navigationDestination 推 AddModelPage(onModelAdded: { loadModelList(reset: true) })
  → 用户填写：模型名称（必填）/ 类型 Picker（默认「ollama模型」）/ 模型地址（必填）/ API Key（在线模型必填）
     isFormValid 变化 → 「确定」按钮在 primaryColor / grayColor 间切换并联动 disabled
     切到「在线模型」→ API Key 行出现红 `*`，占位文案变「请输入API Key」，未填时按钮不可点
  → 点「确定」→ handleAddModel
       ├─ 无 companyId → alert「未找到公司ID」（shouldDismiss 仍为 false，留在本页）
       ├─ 地址不合法 → alert「模型地址格式不正确，需以 http:// 或 https:// 开头」→ 留在本页
       └─ 校验通过 → isSubmitting = true（按钮转圈）
             → POST /service/chat/addModel { modelName, type, companyId, baseUrl, disabled: 0, apiKey? }
             ├─ data > 0（后端成功返回 1）→ 立即 onModelAdded?()（父页 loadModelList(reset: true)）
             │     → alert「添加成功」+ shouldDismiss = true → 点「确定」→ dismiss()
             ├─ data <= 0 → alert「添加失败，请稍后重试」→ 点「确定」留在本页
             └─ .failure → alert(error.localizedDescription) → 留在本页
「取消」→ 直接 dismiss()（不提示、不回调，已填内容丢弃）
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；表单行 `formCardView` + `formRow(label:isRequired:content:)`；按钮 `actionButtonsView`。
- **加表单字段**：① 加 `@State`；② `formCardView` 里加一段 `formRow` + `DividerLine()`；③ 若必填则改 `isFormValid`；④ `HTTPClient.addModel` 加形参并写入 `parameters`；⑤ 确认后端 `AddModelSchema` 支持；⑥ 同步改 [UpdateModelPage](UpdateModelPage.md)（两页表单是复制关系）。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method` 两个 switch 都要补）→ `HTTPClient` 方法 → 页面调用。
- **改模型类型选项**：改 `private let modelTypes`（提交值）+ `private let modelTypeNames`（中文展示），两处必须同步；`ollama` / `online` 是与后端约定的现行口径，后端文档里的 deepseek/tongyi 说明尚未更新。
- **改必填规则**：条件必填统一走计算属性（如 `isApiKeyRequired`），同时驱动 `formRow(isRequired:)` 的红 `*`、占位文案与 `isFormValid`，避免三处不一致。

### 10.1 已知坑

1. **`label` 宽度写死 80**（保持现状）：`formRow` 里 `.frame(width: 80, alignment: .leading)`，更长的中文标签（或大字号辅助功能）会被压缩换行。
2. **`.navigationBarHidden(true)` 重复设置**（保持现状）：父页面 `navigationDestination` 里已对 `AddModelPage()` 加了 `.navigationBarHidden(true)`，本页 body 末尾又加了一次（无害但冗余）。
3. **`companyId` 兜底依赖 `userData`**（保持现状）：`AppState.getCachedCompanyId()` 内部需要 `userData?.id` 拼 key `companyId_<userId>`，若用户数据尚未加载则返回 nil，会直接提示「未找到公司ID」。
4. **与 [UpdateModelPage](UpdateModelPage.md) 不同步**：编辑页与本页表单是复制关系，但本页已有的「类型中文展示、在线模型强制 API Key、模型地址格式校验」三项编辑页都没有；`HTTPClient.updateModel` 也未提交 `disabled`。改本页表单时要同步过去。

## 相关文档

- [ModelManagePage](ModelManagePage.md)（父页面）
- [UpdateModelPage](UpdateModelPage.md)（同构的编辑页）
- 后端接口：`docs/api/chat.md`
