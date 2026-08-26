---
name: change-password-page
description: 修改密码页 —— 输入旧密码/新密码/确认密码，本地校验后调用 updatePassword（密码 md5 后提交），成功后自动关闭。改动该页前先读本文档。
page: ChangePasswordPage.swift
path: chat/chat/UI/Pages/ChangePasswordPage.swift
apis:
  - PUT /service/user/updatePassword
---

# ChangePasswordPage（修改密码）

## 1. 页面职责

`ChangePasswordPage` 是当前登录用户修改登录密码的表单页：输入旧密码、新密码、确认密码，做纯前端校验（非空、长度 ≥6、两次一致、新旧不同）后调用 `updatePassword` 提交。密码在客户端经 MD5 后发送。成功后弹「密码修改成功」提示，点「确定」自动关闭页面。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/ChangePasswordPage.swift`（249 行）
- **入口**：`UserPage` 的「修改密码」按钮 → `showChangePasswordPage = true`，以 `.fullScreenCover` 弹出：

  ```swift
  .fullScreenCover(isPresented: $showChangePasswordPage) {
      ChangePasswordPage()
  }
  ```

- **出口**：无（仅返回，且成功后可自动关闭）。
- **依赖组件**：无（自绘 `formRow` / `DividerLine`）。
- **依赖模型**：无。
- **依赖服务**：`HTTPClient.shared.updatePassword(...)`。

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `dismiss` | `@Environment` | — | 关闭本页 |
| `oldPassword` | `@State String` | `""` | 旧密码输入 |
| `newPassword` | `@State String` | `""` | 新密码输入 |
| `confirmPassword` | `@State String` | `""` | 确认密码输入 |
| `isUpdating` | `@State Bool` | `false` | 提交中（按钮转圈 + 禁用） |
| `showAlert` | `@State Bool` | `false` | 「提示」弹窗 |
| `alertMessage` | `@State String` | `""` | 弹窗文案 |
| `isPasswordMatch` | `private var Bool`（计算） | — | `newPassword == confirmPassword` |
| `isFormValid` | `private var Bool`（计算） | — | 三输入非空 + 匹配 + `newPassword.count >= 6` |

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar（返回按钮 + 标题「修改密码」+ 占位按钮，底部 1px 分隔线）
├─ ScrollView
│  └─ VStack(spacing: middleMargin)
│     ├─ 表单卡片 VStack(spacing: 0)（whiteColor + borderRadius）
│     │   ├─ formRow("旧密码", 必填) → SecureField
│     │   ├─ DividerLine
│     │   ├─ formRow("新密码", 必填) → SecureField + 长度<6 红字提示
│     │   ├─ DividerLine
│     │   └─ formRow("确认密码", 必填) → SecureField + 两次不一致红字提示
│     └─ 「确定」按钮
│        ├─ isUpdating 时显示 ProgressView + 文案「修改中...」
│        ├─ 背景：isFormValid && !isUpdating ? primaryColor : grayColor
│        └─ .disabled(!isFormValid || isUpdating)
├─ background pageBackgroundColor
├─ .navigationBarHidden(true)
└─ .alert("提示", isPresented: $showAlert)   // 确定按钮：文案含"成功"则 dismiss()
```

- `customNavigationBar`：返回箭头 `Colors.subColor`，标题「修改密码」。
- `formRow(label:isRequired:content:)`：左侧标签区（`isRequired` 时带红色 `*`）固定宽 80，右侧 `content` 占满剩余宽度。
- 新密码行：输入非空且 `< 6` 位时显示「密码长度不能少于6位」（`warnColor`，字号 `normalFont - 2`）。
- 确认密码行：输入非空且 `!isPasswordMatch` 时显示「两次输入的密码不一致」（`warnColor`）。

## 5. 核心方法

### `handleUpdatePassword()`
- **触发**：「确定」按钮点击（按钮本身已按 `isFormValid` 禁用，此处再做一次兜底校验）
- **步骤**：
  1. `newPassword.count < 6` → 提示「新密码长度不能少于6位」，返回。
  2. `!isPasswordMatch` → 提示「两次输入的新密码不一致」，返回。
  3. `oldPassword == newPassword` → 提示「新密码不能与旧密码相同」，返回。
  4. `isUpdating = true` → `HTTPClient.shared.updatePassword(oldPassword:newPassword:)`。
- **成功**：`data == 1` → 提示「密码修改成功」；否则提示「密码修改失败，请检查旧密码是否正确」。
- **失败**（`NetworkError`）：提示 `error.localizedDescription`。
- 回调统一 `DispatchQueue.main.async` 并复位 `isUpdating = false`。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `updatePassword` | PUT | `/service/user/updatePassword` | 「确定」按钮点击 | `docs/api/user.md` §5 |

### 6.1 `updatePassword`

- **Swift 签名**：`func updatePassword(oldPassword: String, newPassword: String, completion: @escaping (Result<Int, NetworkError>) -> Void)`
- **APIEndpoint**：`.updatePassword`（`Constants.API.updatePassword = "/service/user/updatePassword"`，method `PUT`）
- **请求**（Body，`[String: Any]`）：

  | 参数 | 类型 | 说明 |
  |---|---|---|
  | `oldPassword` | String | 旧密码（`oldPassword.md5`，客户端 MD5 后提交） |
  | `newPassword` | String | 新密码（`newPassword.md5`） |

- **响应**：`BaseResponse<Int>`，`data` 为整数（客户端以 `data == 1` 判成功）。
- **UI 处理**：成功且 `data == 1` → 提示成功，点「确定」`dismiss()`；否则提示失败文案。

## 7. 数据模型

无自定义模型。请求体为 `[String: Any]`，响应 `BaseResponse<Int>`（即 `NumberData` 场景）。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 表单卡片 / 导航栏底 | `Colors.whiteColor` |
| 卡片圆角 | `Dimens.borderRadius` |
| 确定按钮可用底色 | `Colors.primaryColor` |
| 确定按钮禁用底色 | `Colors.grayColor` |
| 必填 `*` / 校验红字 | `Colors.warnColor` |
| 返回箭头 | `Colors.subColor` |
| 分隔线 | `Colors.grayColor.opacity(0.3)` 高 1 |
| 按钮高 / 圆角 | `Dimens.btnHeight` / `btnHeight/2` |
| 标签列宽 | 写死 `80` |
| 间距 | `Dimens.middleMargin` |

## 9. 交互流程

```
UserPage「修改密码」→ fullScreenCover 弹出
  → 输入三框，实时前端校验（长度<6 / 两次不一致）
  → 「确定」（isFormValid 才可点）
      → handleUpdatePassword 兜底校验（长度/一致/新旧相同）
      → updatePassword（密码 MD5）
          ├─ data == 1：提示「密码修改成功」→ 点确定 dismiss()
          ├─ data != 1：提示「密码修改失败，请检查旧密码是否正确」
          └─ NetworkError：提示 error.localizedDescription
```

## 10. 二次开发指引

- **改文案/样式**：校验红字在各 `formRow` 的 content 闭包内；按钮在 `body`；标题在 `customNavigationBar`。
- **加校验规则**：改 `isFormValid` 计算属性 + `handleUpdatePassword` 兜底分支，两处需同步。
- **已知坑 / 注意事项**：
  1. **成功判据是 `data == 1`，与后端文档不一致**：后端 `docs/api/user.md` §5 的出参示例 `data: null`（仅 `status: SUCCESS`），而客户端 `updatePassword` 要求 `response.data` 非空才 `success`，页面再以 `data == 1` 判成功。若后端只回 `status=SUCCESS` + `data=null`，客户端会走 `failure("修改密码失败")`。这是前后端契约风险点，需与后端确认真实返回。
  2. **密码 MD5 在客户端**：`oldPassword.md5` / `newPassword.md5` 由 `HTTPClient.updatePassword` 完成，页面传的是明文 `@State`。MD5 属弱哈希，非安全存储方案，仅供说明。
  3. **新旧密码一致性校验**依赖明文比对（`oldPassword == newPassword`），发生在 MD5 之前，逻辑正确但若 `oldPassword` 来自登录时已加密存储则不可比（本项目登录态未复用旧密码，无此问题）。
  4. **成功关闭靠字符串匹配**：`alertMessage.contains("成功")` 决定是否 `dismiss()`，属脆弱的魔法判断；若将来成功文案去掉「成功」二字则不再自动关闭。
  5. **按钮与兜底校验重复**：`isFormValid` 已含长度/匹配校验，`handleUpdatePassword` 又重复一遍，可保留但需注意两处口径一致（当前一致）。
