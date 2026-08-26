---
name: add-prompt-page
description: 新增提示词页（AddPromptPage）。TextEditor 录入提示词内容并调用 insertPrompt 按租户新增；需要改提示词录入校验或新增后刷新回调时读这份文档。
page: AddPromptPage.swift
path: chat/chat/UI/Pages/AddPromptPage.swift
apis:
  - POST /service/prompt/insertPrompt
---

# AddPromptPage（添加提示词页）

## 1. 页面职责

`AddPromptPage` 是单字段表单页：一个多行 `TextEditor` 录入提示词正文，提交给 `/service/prompt/insertPrompt`，为当前租户（`AppState.currentTenant`）新增一条提示词。

它只能从 [PromptManagePage](PromptManagePage.md) 的导航栏「+」进入。构造函数支持 `onPromptAdded` 回调（源码注释写「添加成功后通知父页面刷新」），**但父页面当前没有传这个回调**，因此新增成功后列表不会自动刷新（见 10.1）。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/AddPromptPage.swift`（约 226 行）
- **入口**：`PromptManagePage` 的
  `navigationDestination(isPresented: $showAddPromptPage) { AddPromptPage().navigationBarHidden(true) }`
  —— 未传 `onPromptAdded`
- **出口**：仅 `dismiss()` 返回 `PromptManagePage`
- **依赖组件**：无外部组件（`TextEditor` + 手写占位文字）
- **依赖模型**：无（提交纯字符串，成功返回值转成 `Bool`）
- **依赖服务**：`HTTPClient.shared.insertPrompt`、`AppState.shared`（`currentTenant`）、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 取 `currentTenant?.id` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 返回上一页 |
| `onPromptAdded` | `(() -> Void)?`（`let`，构造参数） | `nil` | 添加成功后通知父页面刷新（当前调用方未传） |
| `promptText` | `String`（`@State`） | `""` | 提示词正文 |
| `isSubmitting` | `Bool`（`@State`） | `false` | 提交中（按钮转圈并禁用） |
| `showAlert` | `Bool`（`@State`） | `false` | 提示弹窗开关 |
| `alertMessage` | `String`（`@State`） | `""` | 提示内容 |
| `shouldDismiss` | `Bool`（`@State`） | `false` | 标记「弹窗确认后回调 + 关页」 |

构造函数：`init(onPromptAdded: (() -> Void)? = nil)`（源码注释「✅ 新增：支持无回调初始化」）。

本页没有独立的 `isFormValid` 计算属性，校验逻辑直接内联在按钮上：`promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`。

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar        whiteColor 底 / 上下左右 middleMargin / 底部 1px grayColor.opacity(0.3)
│   ├─ 返回 chevron.left（Colors.subColor，middleIcon）→ dismiss()
│   ├─ 标题「添加提示词」（middleFont / .black）
│   └─ Color.clear 占位（middleIcon × middleIcon）
└─ ScrollView（背景 pageBackgroundColor）
   └─ VStack(spacing: middleMargin)，四周 middleMargin 内边距
      ├─ promptCardView       whiteColor + borderRadius 圆角，内边距 middleMargin
      │   ├─ Text「提示词内容」（normalFont / .black）
      │   └─ ZStack(alignment: .topLeading)
      │       ├─ TextEditor(text: $promptText)
      │       │     normalFont / .black / minHeight 200 / 内边距 middleMargin
      │       │     .scrollContentBackground(.hidden) + .background(.white)
      │       │     .cornerRadius(borderRadius) + 描边 RoundedRectangle(borderRadius).stroke(grayColor, 1)
      │       └─ promptText.isEmpty → Text「请输入提示词内容...」
      │             grayColor / padding(.horizontal, middleMargin + 5) / padding(.vertical, middleMargin + 8)
      │             .allowsHitTesting(false)
      └─ actionButtonsView    HStack(spacing: middleMargin)
          ├─ 「取消」透明底 + grayColor 描边/文字，高 btnHeight，圆角 btnHeight/2 → dismiss()
          └─ 「确定」trim 后为空 ? grayColor : primaryColor，白字，圆角 btnHeight/2
                提交中显示白色 ProgressView
                .disabled(trim 后为空 || isSubmitting)
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) { if shouldDismiss { onPromptAdded?(); dismiss() } } }
└─ .navigationBarHidden(true)
```

与 [PromptManagePage](PromptManagePage.md) 编辑弹窗里的 `TextEditor` 是同一套写法（同样的 `minHeight: 200`、同样的占位文字与偏移量），区别是本页外面套的是卡片而非 `CustomDialog`。

### 4.1 占位文字的实现方式

SwiftUI 的 `TextEditor` 原生不支持 placeholder，本页用 `ZStack(alignment: .topLeading)` 把一段 `Text` 叠在编辑器左上角：

- 显示条件：`promptText.isEmpty`（注意是**原始文本**是否为空，不是 trim 后）
- `allowsHitTesting(false)`：让点击穿透到底层 `TextEditor`
- 位置靠 `padding(.horizontal, Dimens.middleMargin + 5)` / `padding(.vertical, Dimens.middleMargin + 8)` 手动对齐 `TextEditor` 的内部文字基线（魔法数字，见 10.1）
- `TextEditor` 侧用 `.scrollContentBackground(.hidden)` + `.background(.white)` 才能盖掉系统默认背景，圆角与描边分别由 `.cornerRadius(Dimens.borderRadius)` 和 `RoundedRectangle(cornerRadius: Dimens.borderRadius).stroke(Colors.grayColor, lineWidth: 1)` 提供

### 4.2 actionButtonsView 的三种按钮态

| 条件 | 「确定」按钮表现 |
|---|---|
| `promptText` trim 后为空 | 背景 `Colors.grayColor`，`disabled` |
| 有内容且 `isSubmitting == false` | 背景 `Colors.primaryColor`，白色「确定」文字，可点 |
| `isSubmitting == true` | 背景仍是 `Colors.primaryColor`，内容替换为白色 `ProgressView`，`disabled` |

「取消」按钮任何时候都可点（透明底 + `Colors.grayColor` 描边），直接 `dismiss()`，不做二次确认。

## 5. 核心方法

### `handleAddPrompt()`
- **触发**：「确定」按钮点击（`Button(action: handleAddPrompt)`）
- **步骤**：
  1. `let trimmedText = promptText.trimmingCharacters(in: .whitespacesAndNewlines)`
  2. `guard !trimmedText.isEmpty else { alertMessage = "提示词不能为空"; showAlert = true; return }`（按钮本身已 disabled，这是二次防御）
  3. `guard let tenantId = appState.currentTenant?.id else { alertMessage = "未找到租户ID"; showAlert = true; return }`
  4. `isSubmitting = true`
  5. 调 `HTTPClient.shared.insertPrompt(prompt: trimmedText, tenantId: tenantId)`
  6. 回调内 `DispatchQueue.main.async`，先 `isSubmitting = false`
     - `success == true` → `alertMessage = "添加成功"`、`shouldDismiss = true`、`showAlert = true`
     - `success == false` → `alertMessage = "添加失败，请稍后重试"`、`showAlert = true`
     - `.failure` → `alertMessage = error.localizedDescription`、`showAlert = true`
- **失败处理**：都走同一个 `alert`；只有 `shouldDismiss == true` 时点「确定」才 `onPromptAdded?()` + `dismiss()`，失败时留在本页保留已输入内容。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `insertPrompt` | POST | `/service/prompt/insertPrompt` | 点击「确定」 | `docs/api/prompt.md` |

### 6.1 `insertPrompt`

- **Swift 签名**：`func insertPrompt(prompt: String, tenantId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void)`
- **APIEndpoint**：`.insertPrompt`（`path` = `Constants.API.insertPrompt` = `/service/prompt/insertPrompt`；`method` = `"POST"`）
- **请求**：POST → `parameters` 序列化成 JSON Body（`Content-Type: application/json`），鉴权靠 `Authorization: Bearer <token>`，网关解析出 `X-User-Id` 透传给 prompt-service（`userId` 客户端不传）

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `prompt` | Body | String | 是 | 提示词正文（已 trim） |
| `tenantId` | Body | String | 是 | 当前租户 ID |

  与后端 `InsertPromptSchema`（字段：`tenantId`、`prompt`）完全对齐。
- **响应**：`BaseResponse<Int>`；`HTTPClient` 内部 `if response.isSuccess, let data = response.data { completion(.success(data > 0)) }`，否则 `.failure(.custom(message: response.msg ?? "添加提示词失败"))`。后端文档「新增提示词」出参示例为 `"data": null`（见 10.1）。
- **接口差异备注**：`prompt.md` 特别注明「`insertPrompt` 由 Spring 的 PUT 改为 POST」，客户端 `APIEndpoint.method` 里 `.insertPrompt` 归在 POST 分支，一致。
- **UI 处理**：见 `handleAddPrompt`。

## 7. 数据模型

本页不构造 `Prompt` 对象，只提交两个字符串字段。字段语义对照 `Models/Prompt.swift` 与后端 `prompt` 表：

| 表单/提交字段 | Prompt 字段 | 后端表列 | 说明 |
|---|---|---|---|
| 提示词内容 | `prompt` | `prompt` varchar(255) | 必填，trim 后非空 |
| （隐式）租户 | `tenantId` | `tenant_id` varchar(32) | 取 `appState.currentTenant?.id` |
| （后端补） | `userId` | `user_id` varchar(32) | 由网关 `X-User-Id` 注入，客户端不传 |
| （后端补） | `id` / `createTime` / `updateTime` | `id` / `create_time` / `update_time` | 后端生成 |

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏 | `Colors.whiteColor` 底 + 底部 1px `Colors.grayColor.opacity(0.3)` |
| 返回图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题「添加提示词」 | `Dimens.middleFont`，`.black` |
| 卡片 | `Colors.whiteColor` + `Dimens.borderRadius`，内边距 `Dimens.middleMargin` |
| 卡片标题「提示词内容」 | `Dimens.normalFont`，`.black` |
| TextEditor | `Dimens.normalFont`，`minHeight: 200`，`Dimens.borderRadius` 圆角 + `Colors.grayColor` 1px 描边，白底 |
| 占位文字 | `Colors.grayColor`，`Dimens.normalFont` |
| 取消按钮 | 透明底 + `Colors.grayColor` 描边与文字，高 `Dimens.btnHeight`，圆角 `btnHeight / 2` |
| 确定按钮 | 有内容 `Colors.primaryColor` / 空 `Colors.grayColor`，白字，高 `Dimens.btnHeight`，圆角 `btnHeight / 2` |

## 9. 交互流程

```
PromptManagePage 导航栏「+」→ showAddPromptPage = true
  → navigationDestination 推 AddPromptPage()（⚠️ 未传 onPromptAdded）
  → 用户在 TextEditor 输入正文
     promptText 非空白 → 「确定」由 grayColor 变 primaryColor 并解除 disabled
  → 点「确定」→ handleAddPrompt
       ├─ trim 后为空 → alert「提示词不能为空」
       ├─ 无 currentTenant → alert「未找到租户ID」
       └─ isSubmitting = true（按钮转圈）
             → POST /service/prompt/insertPrompt  Body { prompt, tenantId }
             ├─ data > 0 → alert「添加成功」+ shouldDismiss = true
             │     → 点 alert「确定」→ onPromptAdded?()（当前为 nil）→ dismiss()
             │     → 回到 PromptManagePage：列表不会自动刷新，需手动下拉
             ├─ data <= 0 → alert「添加失败，请稍后重试」，留在本页
             └─ .failure → alert(error.localizedDescription)，留在本页
「取消」→ 直接 dismiss()（不提示、不回调，已输入内容丢弃）
```

### 9.1 shouldDismiss 状态机

`shouldDismiss` 决定 `alert` 的「确定」按钮是「只关弹窗」还是「关弹窗 + 回调 + 关页」：

| 场景 | `alertMessage` | `shouldDismiss` | 点 alert「确定」后 |
|---|---|---|---|
| 内容为空（防御分支） | 提示词不能为空 | `false` | 仅关弹窗，留在本页 |
| 无 `currentTenant` | 未找到租户ID | `false` | 仅关弹窗，留在本页 |
| 接口成功且 `data > 0` | 添加成功 | `true` | `onPromptAdded?()` + `dismiss()` |
| 接口成功但 `data <= 0` | 添加失败，请稍后重试 | `false` | 仅关弹窗，输入内容保留 |
| 网络/业务失败 | `error.localizedDescription` | `false` | 仅关弹窗，输入内容保留 |

`shouldDismiss` 一旦被置 `true` 就不会复位，但成功后立即 `dismiss()`，页面销毁，`@State` 随之释放，不会残留。

## 10. 二次开发指引

- **改文案/样式**：导航栏 `customNavigationBar`；输入卡片 `promptCardView`（含占位文字偏移 `middleMargin + 5` / `middleMargin + 8`）；按钮 `actionButtonsView`。
- **加字段**（例如提示词标题/分类）：① 加 `@State`；② `promptCardView` 里加控件；③ 校验逻辑（当前内联在按钮的 `background` / `disabled` 里，建议顺手抽成 `isFormValid` 计算属性，与 [AddModelPage](AddModelPage.md) 保持一致）；④ `HTTPClient.insertPrompt` 加形参并写入 `parameters`；⑤ 后端 `InsertPromptSchema` 同步。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method` 两个 switch）→ `HTTPClient` 方法 → 页面调用。
- **让新增后父页面刷新**：改 `PromptManagePage` 的跳转为
  `AddPromptPage(onPromptAdded: { loadPromptList(reset: true) })` —— 本页已经支持，只差调用方传参。

### 10.1 已知坑

1. **`onPromptAdded` 回调形同虚设**：`PromptManagePage` 里写的是 `AddPromptPage()`，没有传回调；而父页面的 `.onAppear { loadPromptList() }` 挂在 `NavigationStack` 外层，pop 返回不会重新触发。结果：**添加成功后列表看不到新数据**，必须下拉刷新。对比 `ModelManagePage` → `AddModelPage(onModelAdded:)` 的正确写法。
2. **成功判定与后端出参不一致**：`HTTPClient.insertPrompt` 要求 `BaseResponse<Int>.data` 非 nil 才判 `data > 0`；后端 `prompt.md`「新增提示词」出参示例是 `"data": null`。若后端确实返回 null，会走 `.failure(.custom(message: msg ?? "添加提示词失败"))`，出现「其实插入成功了却提示添加失败」。需与后端统一返回受影响行数。
3. **`tenantId` 没有缓存兜底**：只用 `appState.currentTenant?.id`，没有像模型页那样 `?? appState.getCachedTenantId()`（`AppState` 提供了 `getCachedTenantId()`，缓存 key `current_tenant_id`）。冷启动/状态丢失时会直接提示「未找到租户ID」而无法添加。
4. **无长度限制**：后端表 `prompt.prompt` 是 `varchar(255)`，但 `TextEditor` 不限字数、界面也没有计数提示，超长内容只能等后端报错。建议加 `onChange` 截断 + 字数显示。
5. **占位文字靠手写 ZStack 叠加**：`padding(.horizontal, middleMargin + 5)`、`padding(.vertical, middleMargin + 8)` 是与 `TextEditor` 内部文字位置对齐的**魔法数字**，改字号或内边距时占位文字会错位。同样的代码在 `PromptManagePage.editPromptDialog` 里还有一份（复制关系），建议抽公共组件。
6. **无 `isFormValid` 计算属性**：`promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` 在 `background` 与 `disabled` 两处重复计算，与 `AddModelPage` / `UpdateModelPage` 的写法不统一。
7. **成功后必须点弹窗才回调/关页**：`onPromptAdded?()` + `dismiss()` 都写在 `alert` 的「确定」按钮里（依赖 `shouldDismiss`）；若改成 toast 等实现，必须把这两句一起迁移。
8. **`.navigationBarHidden(true)` 重复**：父页面在 `navigationDestination` 里已加，本页 body 末尾又加了一次（无害但冗余）。
9. **「取消」无二次确认**：已输入大段提示词时点「取消」会直接丢弃，无「是否放弃编辑」提示。

## 相关文档

- [PromptManagePage](PromptManagePage.md)（父页面，含编辑与删除；删除接口存在真实 bug）
- [AddModelPage](AddModelPage.md)（同批次表单页，可对比校验写法）
- 后端接口：`docs/api/prompt.md`
