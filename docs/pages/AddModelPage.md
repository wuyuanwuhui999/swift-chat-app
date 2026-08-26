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

- **源码**：`chat/chat/UI/Pages/AddModelPage.swift`（约 296 行）
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
| `modelTypes` | `[String]`（`private let`） | `["ollama", "online"]` | Picker 选项 |

计算属性 `isFormValid`：`modelName` 与 `baseUrl` 去首尾空白后都非空（`modelType` 有默认值、`apiKey` 可选，均不参与校验）。

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
      │   ├─ DividerLine()
      │   ├─ formRow「模型地址」必填 → TextField(prompt:「请输入模型地址」) .autocapitalization(.none)
      │   ├─ DividerLine()
      │   └─ formRow「API Key」非必填 → TextField(prompt:「请输入API Key（可选）」) .autocapitalization(.none)
      └─ actionButtonsView     HStack(spacing: middleMargin)
          ├─ 「取消」透明底 + grayColor 描边/文字，高 btnHeight，圆角 btnHeight/2 → dismiss()
          └─ 「确定」isFormValid ? primaryColor : grayColor，白字，圆角 btnHeight/2
                提交中显示白色 ProgressView；.disabled(!isFormValid || isSubmitting)
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) { if shouldDismiss { onModelAdded?(); dismiss() } } }
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
  3. `isSubmitting = true`
  4. 调 `HTTPClient.shared.addModel(modelName:type:companyId:apiKey:baseUrl:)`，`apiKey` 传 `trimmedApiKey.isEmpty ? nil : trimmedApiKey`
  5. 回调内 `DispatchQueue.main.async`：先 `isSubmitting = false`
     - 成功且 `data > 0` → `alertMessage = "添加成功"`、`shouldDismiss = true`、`showAlert = true`
     - 成功但 `data <= 0` → `alertMessage = "添加失败，请稍后重试"`、`showAlert = true`（`shouldDismiss` 保持 false）
     - 失败 → `alertMessage = error.localizedDescription`、`showAlert = true`
- **失败处理**：全部通过同一个 `alert` 展示；只有 `shouldDismiss == true` 时点「确定」才会 `onModelAdded?()` + `dismiss()`，失败时留在表单页保留已填内容。

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
      completion: @escaping (Result<Int, NetworkError>) -> Void
  )
  ```
- **APIEndpoint**：`.addModel`（`path` = `Constants.API.addModel` = `/service/chat/addModel`；`method` = `"POST"`，与 `.insertPrompt` 等归在同一 POST 分支）
- **请求**：POST → `HTTPClient.request` 把 `parameters` 序列化成 JSON Body（`Content-Type: application/json`）

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `modelName` | Body | String | 是 | 模型名称 |
| `type` | Body | String | 是 | 本页可选值只有 `ollama` / `online` |
| `companyId` | Body | String | 是 | 来自 `currentCompany?.id ?? getCachedCompanyId()` |
| `baseUrl` | Body | String | 是 | 模型 API 基础路径 |
| `apiKey` | Body | String | 否 | 仅当非 nil 且非空才写入 `parameters` |

- **响应**：`BaseResponse<Int>`，`HTTPClient` 要求 `isSuccess && data != nil` 才回调 `.success(data)`，否则 `.failure(.custom(message: response.msg ?? "添加模型失败"))`。
  后端文档 `chat.md`「新增模型」出参示例是 `"data": null`（见 10.1）。
- **后端字段对照**（`chat.md` → `AddModelSchema / UpdateModelSchema`）：`type` / `apiKey` / `modelName` / `baseUrl` / `disabled` / `companyId`。其中 `disabled`（0 启用 / 1 禁用）**客户端不传**。
- **权限**：后端标注「添加模型（需企业管理员权限）」，客户端侧的权限控制体现在 `HomePage` 只对管理员显示「模型管理」入口。
- **UI 处理**：见 `handleAddModel`。

## 7. 数据模型

本页不直接使用 `ChatModel`（只提交字段、只解析 `Int`），但字段语义与 `Models/ChatModel.swift` 一一对应：

| 表单字段 | ChatModel 字段 | 类型 | 说明 |
|---|---|---|---|
| 模型名称 | `modelName` | `String` | 必填 |
| 模型类型 | `type` | `String` | 注释写「ollama 或 online」 |
| 模型地址 | `baseUrl` | `String` | 必填 |
| API Key | `apiKey` | `String?` | 可选，为空时不提交该字段 |
| （隐式） | `companyId` | `String` | 取自全局状态 |

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
  → 用户填写：模型名称（必填）/ 类型 Picker（默认 ollama）/ 模型地址（必填）/ API Key（可选）
     isFormValid 变化 → 「确定」按钮在 primaryColor / grayColor 间切换并联动 disabled
  → 点「确定」→ handleAddModel
       ├─ 无 companyId → alert「未找到公司ID」（shouldDismiss 仍为 false，留在本页）
       └─ 有 companyId → isSubmitting = true（按钮转圈）
             → POST /service/chat/addModel
             ├─ data > 0 → alert「添加成功」+ shouldDismiss = true
             │     → 点 alert「确定」→ onModelAdded?()（父页 loadModelList(reset: true)）→ dismiss()
             ├─ data <= 0 → alert「添加失败，请稍后重试」→ 点「确定」留在本页
             └─ .failure → alert(error.localizedDescription) → 留在本页
「取消」→ 直接 dismiss()（不提示、不回调，已填内容丢弃）
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；表单行 `formCardView` + `formRow(label:isRequired:content:)`；按钮 `actionButtonsView`。
- **加表单字段**：① 加 `@State`；② `formCardView` 里加一段 `formRow` + `DividerLine()`；③ 若必填则改 `isFormValid`；④ `HTTPClient.addModel` 加形参并写入 `parameters`；⑤ 确认后端 `AddModelSchema` 支持；⑥ 同步改 [UpdateModelPage](UpdateModelPage.md)（两页表单是复制关系）。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method` 两个 switch 都要补）→ `HTTPClient` 方法 → 页面调用。
- **改模型类型选项**：只需改 `private let modelTypes`，但要同时和后端 `type` 取值口径对齐（见下）。

### 10.1 已知坑

1. **`modelTypes` 与后端 type 枚举不一致**：本页只有 `["ollama", "online"]`，而后端文档 `chat.md` 的 `AddModelSchema` 说明是「大模型类型（ollama/deepseek/tongyi）」，表 `chat_model.type` 注释为「ollama 本地大模型 / deepseek / tongyi 在线大模型」，`getModelList` 出参示例里 `type` 是 `"deepseek"`。客户端提交 `"online"` 后端不一定能识别；应统一口径（要么后端接受 `online`，要么客户端改成 deepseek/tongyi 等具体厂商）。
2. **成功判定与后端出参不一致**：客户端要求 `BaseResponse<Int>.data` 非 nil 且 `> 0`，而后端文档「新增模型」出参示例为 `"data": null`。若后端确实返回 null，`HTTPClient.addModel` 会走 `.failure(.custom(message: msg ?? "添加模型失败"))`，用户看到失败提示但数据已入库。需与后端确认返回受影响行数。
3. **`online` 类型未强制要求 API Key**：`isFormValid` 只校验名称与地址；选 `online` 却不填 `apiKey` 时，`apiKey` 不会进 Body，在线模型将缺少凭证。建议按 `modelType == "online"` 条件必填。
4. **`baseUrl` 无格式校验**：只做了 `trimmingCharacters` 和非空判断，不校验 `http(s)://` 前缀或 URL 合法性，错误地址要等实际聊天时才暴露。
5. **不传 `disabled`**：后端 Schema 有 `disabled`（0/1），本页新增时不传，依赖数据库/后端默认值；如果后端未设默认值，新模型的启用状态不确定。
6. **`label` 宽度写死 80**：`formRow` 里 `.frame(width: 80, alignment: .leading)`，更长的中文标签（或大字号辅助功能）会被压缩换行。
7. **Picker 直接显示原始枚举值**：`Text(type)` 展示 `ollama` / `online`，没有中文映射，与页面其它中文文案风格不一致。
8. **成功后必须点弹窗才刷新**：刷新与关页都写在 `alert` 的「确定」按钮里（依赖 `shouldDismiss`）。若把 `alert` 换成 toast 之类的实现，必须把 `onModelAdded?()` + `dismiss()` 一起迁移，否则父页面列表不会刷新。
9. **`.navigationBarHidden(true)` 重复设置**：父页面 `navigationDestination` 里已对 `AddModelPage()` 加了 `.navigationBarHidden(true)`，本页 body 末尾又加了一次（无害但冗余）。
10. **`companyId` 兜底依赖 `userData`**：`AppState.getCachedCompanyId()` 内部需要 `userData?.id` 拼 key `companyId_<userId>`，若用户数据尚未加载则返回 nil，会直接提示「未找到公司ID」。

## 相关文档

- [ModelManagePage](ModelManagePage.md)（父页面）
- [UpdateModelPage](UpdateModelPage.md)（同构的编辑页）
- 后端接口：`docs/api/chat.md`
