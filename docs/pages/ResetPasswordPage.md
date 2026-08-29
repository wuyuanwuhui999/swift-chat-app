---
name: reset-password-page
description: 重置密码页（新密码 + 确认密码 + 邮箱验证码，成功即登录）。当你需要改重置密码流程、密码强度校验，或排查「重置成功后没进公司页」问题时读这份文档。
page: ResetPasswordPage.swift
path: chat/chat/UI/Pages/ResetPasswordPage.swift
apis:
  - POST /service/user/resetPassword
---

# ResetPasswordPage（重置密码页）

## 1. 页面职责

密码找回链路的**第二步**（终点）：接收上一页传来的邮箱，收集**新密码 + 确认密码 + 邮箱验证码**三项，调 `resetPassword` 完成重置。

重置成功后服务端会连带下发用户信息与 token，页面直接把它们写进 `AppState`，然后全屏推进 `CompanyPage` —— 也就是**重置密码即完成登录**，用户不需要再回登录页输一遍。

本页是唯一接收构造参数（`let email: String`）的认证页，也是密码链路上唯一做「密码长度不少于 6 位」校验的页面。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/ResetPasswordPage.swift`（约 243 行，含 `#Preview`）
- **入口**：[ForgetPasswordPage](ForgetPasswordPage.md) 发送验证码成功后延迟 1.5 秒
  `navigateToReset = true` → `navigationDestination(isPresented:)` **push** 出 `ResetPasswordPage(email: email)`
- **出口**：
  - `CompanyPage`（`fullScreenCover`，`navigateToCompanyPage`）—— 重置成功
  - 返回 `ForgetPasswordPage`：导航栏左侧 `chevron.left` → `@Environment(\.dismiss)`
- **依赖组件**：**无外部组件**。导航栏、分割线、表单行都是页内私有实现
  （`customNavigationBar`、`DividerLine()`、`formRow(label:isRequired:content:)`）
- **依赖模型**：`Models/User.swift`（整体传递，不读单字段）、`Models/BaseResponse.swift`、`Models/AppState.swift`、`LoginResponse`
- **依赖服务**：
  - `HTTPClient.shared.resetPassword(email:password:code:completion:)`
  - `AppState.shared.updateUserData(_:)` / `updateToken(_:)`

## 3. 状态定义

**构造参数与环境**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `email`（`let`，非私有） | `String` | 由上页传入 | 重置目标邮箱，**页面内只读、不可编辑、界面上也不展示** |
| `appState`（`@ObservedObject private`） | `AppState` | `AppState.shared` | 重置成功后写用户信息与 token |
| `dismiss`（`@Environment(\.dismiss) private`） | `DismissAction` | — | 导航栏返回按钮关闭本页 |

**表单与流程状态（`@State private`）**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `newPassword` | `String` | `""` | 新密码（`SecureField`） |
| `confirmPassword` | `String` | `""` | 确认密码（`SecureField`） |
| `verificationCode` | `String` | `""` | 邮箱验证码（`keyboardType(.numberPad)`） |
| `isResetting` | `Bool` | `false` | 重置请求中；按钮显示 `ProgressView` + 文案「重置中...」并禁用 |
| `showAlert` | `Bool` | `false` | 通用提示弹窗开关 |
| `alertMessage` | `String` | `""` | 弹窗文案 |
| `navigateToCompanyPage` | `Bool` | `false` | 控制 `CompanyPage` 的 `fullScreenCover` |

**计算属性**

| 属性 | 类型 | 规则 |
|---|---|---|
| `isPasswordMatch`（`private var`） | `Bool` | `newPassword == confirmPassword` |
| `isFormValid`（`private var`） | `Bool` | `!newPassword.isEmpty && !confirmPassword.isEmpty && !verificationCode.isEmpty && isPasswordMatch` |

无 `@StateObject` / `@Binding`。

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar                              白底 + 底部 1px 分隔线
└─ ScrollView                                       背景 Colors.pageBackgroundColor
   └─ VStack(spacing: Dimens.middleMargin)
      │   .padding(.horizontal, Dimens.middleMargin) .padding(.top, Dimens.middleMargin)
      ├─ 表单卡片 VStack(spacing: 0)
      │  │   .background(Colors.whiteColor) .cornerRadius(Dimens.borderRadius)
      │  ├─ formRow「新密码」*   SecureField「请输入新密码」 字号 normalFont
      │  ├─ DividerLine()
      │  ├─ formRow「确认密码」* VStack(alignment: .trailing, spacing: Dimens.smallIcon)
      │  │     SecureField「请再次输入新密码」
      │  │     if !isPasswordMatch && !confirmPassword.isEmpty
      │  │        → Text「两次输入的密码不一致」 字号 normalFont-2，色 warnColor
      │  ├─ DividerLine()
      │  └─ formRow「验证码」*   TextField「请输入验证码」 .keyboardType(.numberPad)
      └─ Button(handleResetPassword) 确定
            HStack(spacing: Dimens.smallIcon)：isResetting → ProgressView(tint: .white)
            文案 isResetting ? "重置中..." : "确定"，色 Colors.whiteColor
            高 Dimens.btnHeight，底 (isFormValid && !isResetting) ? primaryColor : grayColor
            圆角 Dimens.btnHeight / 2
            .disabled(!isFormValid || isResetting)
            .padding(.bottom, Dimens.middleMargin)

修饰器（挂在最外层 VStack 上）
├─ .background(Colors.pageBackgroundColor)
├─ .navigationBarHidden(true)                       隐藏系统导航栏（本页由上页 NavigationStack 推出）
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) } message: { Text(alertMessage) }
└─ .fullScreenCover(isPresented: $navigateToCompanyPage) { CompanyPage() }
```

**子视图 / 私有构建器**

```
customNavigationBar: HStack
├─ Button(dismiss) chevron.left  字号 Dimens.middleIcon(30)，色 Colors.subColor
├─ Spacer()
├─ Text「重置密码」              字号 Dimens.middleFont(20)，色 .black
├─ Spacer()
└─ Button 占位（chevron.left 透明色，disabled(true)）—— 保持标题居中
   .padding(.horizontal/.vertical, Dimens.middleMargin) .background(Colors.whiteColor)
   .overlay(Rectangle().fill(Colors.grayColor.opacity(0.3)).frame(height: 1), alignment: .bottom)

DividerLine(): Rectangle().fill(Colors.grayColor.opacity(0.3)).frame(height: 1)
               .padding(.leading, Dimens.middleMargin)

formRow(label:isRequired:content:): HStack(alignment: .center, spacing: Dimens.middleMargin)
├─ 标签 HStack(spacing: 2)：isRequired 时前置 Text("*") 色 Colors.warnColor
│     Text(label) 字号 normalFont 黑色
│     .frame(width: 80, alignment: .leading)      ← 与 RegisterPage 一致，ForgetPasswordPage 没有
└─ content.frame(maxWidth: .infinity, alignment: .leading)
   .padding(.horizontal/.vertical, Dimens.middleMargin)
```

> 三个字段全部必填（都带红色 `*`），页面上**没有展示目标邮箱**，也**没有重新发送验证码的入口**。

## 5. 核心方法

### `isPasswordMatch`（计算属性）
- **签名**：`private var isPasswordMatch: Bool`
- **触发**：`body` 每次求值（错误文案 + `isFormValid` 都读它）
- **步骤**：`newPassword == confirmPassword`
- **注意**：两个都为空时也返回 `true`，靠 `isFormValid` 的非空判断兜底；错误文案仅在 `!confirmPassword.isEmpty` 时展示

### `isFormValid`（计算属性）
- **签名**：`private var isFormValid: Bool`
- **规则**：`!newPassword.isEmpty && !confirmPassword.isEmpty && !verificationCode.isEmpty && isPasswordMatch`
- **影响**：确定按钮底色与 `disabled`
- **注意**：**不包含 6 位长度校验**，长度只在 `handleResetPassword()` 里做提交时拦截

### `handleResetPassword()`
- **签名**：`private func handleResetPassword()`
- **触发**：「确定」按钮点击
- **步骤**：
  1. **兜底校验（按顺序 early return）**：
     - `!isPasswordMatch` → `alertMessage = "两次输入的密码不一致"` + `showAlert = true` + return
     - `newPassword.count < 6` → `alertMessage = "密码长度不能少于6位"` + `showAlert = true` + return
  2. `isResetting = true`
  3. `HTTPClient.shared.resetPassword(email: email, password: newPassword, code: verificationCode)`
     （**MD5 在 `HTTPClient` 内部对 `password` 做**）
  4. 回调内 `DispatchQueue.main.async` → `self.isResetting = false`
  5. `.success(let loginResponse)`：
     1. `self.appState.updateUserData(loginResponse.userData)`
     2. `self.appState.updateToken(loginResponse.token)`（内部会 `TokenManager.shared.saveToken` 并置 `isLoggedIn = true`）
     3. `self.navigateToCompanyPage = true` → `fullScreenCover` 弹 `CompanyPage`
  6. `.failure(let error)`：`self.alertMessage = error.localizedDescription` + `showAlert = true`
- **失败处理**：弹 `alert`，三项输入全部保留，用户可改验证码后重试（**但无法在本页重发验证码**）

本页**没有其它 `private func`**（`DividerLine()` / `formRow(...)` 是视图构建器，见 §4）。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `resetPassword` | POST | `/service/user/resetPassword` | 点「确定」且通过两道兜底校验 | `docs/api/user.md` §7 |

该接口在后端**鉴权白名单**内（无需 token）。

### 6.1 `resetPassword`

- **Swift 签名**：`func resetPassword(email: String, password: String, code: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void)`（`HTTPClient.swift` 第 874 行）
- **APIEndpoint**：`.resetPassword` → `Constants.API.resetPassword = "/service/user/resetPassword"`，method `"POST"`
- **底层**：`request(endpoint: .resetPassword, parameters: parameters)`，POST 时 `parameters` 经 `JSONSerialization` 变成 JSON body
- **请求**（JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `email` | Body | String | 是 | 由 [ForgetPasswordPage](ForgetPasswordPage.md) 透传的构造参数，用户在本页无法修改 |
| `password` | Body | String | 是 | `password.md5`（`HTTPClient` 内 `"password": password.md5`，CommonCrypto `CC_MD5`） |
| `code` | Body | String | 是 | 邮箱验证码，客户端只校验非空（无长度/纯数字校验） |

  后端实体为 `ResetPasswordConfirm`（`email` / `code` / `password`），字段名与客户端完全对齐。

- **响应**：`BaseResponse<User>`。客户端判定成功需
  `response.isSuccess && response.data != nil && response.token != nil`，才组装
  `LoginResponse(userData:token:)`；否则转 `NetworkError.custom(message: response.msg ?? "重置密码失败")`。
  > **与后端文档的差异**：`docs/api/user.md` §7 的出参示例里 `data` 与 `token` 都是 `null`。
  > 若后端确实不回 `data` / `token`，客户端会把「重置成功」判成失败并弹「重置密码失败」。
  > 这里以客户端解码结构为准描述，后端文档示例可能是简化写法，联调时优先看真实报文。
- **UI 处理**：
  - 成功 → `AppState.userData` + `AppState.token`（`updateToken` 内部 `saveToken` + `isLoggedIn = true`）→ 弹 `CompanyPage`
  - 失败 → `alert(error.localizedDescription)`
  - **不写任何 `UserDefaults` 业务缓存**（租户/模型/公司 ID 由后续页面处理）

## 7. 数据模型

- `LoginResponse`（`HTTPClient.swift` 第 1608 行，本地组装体、非 Codable）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `userData` | `User` | 由 `BaseResponse.data` 解出 |
| `token` | `String` | 由 `BaseResponse.token` 解出，重置成功后即登录凭证 |

- `User`（`Models/User.swift`）：本页只做整体传递（`appState.updateUserData`），不读取单个字段。
  非可选字段：`userAccount` / `username` / `telephone` / `email` / `sex` / `sign`；
  可选字段：`id` / `createDate` / `updateDate` / `avater` / `birthday` / `role` / `password` / `region` / `disabled` / `permission`。
- `BaseResponse<T>`：`data` / `token` / `status` / `msg` / `total` + `isSuccess`。
- `NetworkError`：`custom(message:)` 承载后端 `msg`，`unauthorized` 对应 HTTP 401，`serverError(statusCode:)` 对应其它非 2xx。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景（VStack + ScrollView 各设一次） | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor` |
| 导航栏内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 导航栏返回图标 | `chevron.left`，字号 `Dimens.middleIcon`(30)，色 `Colors.subColor` |
| 导航栏标题「重置密码」 | `Dimens.middleFont`(20)，`.black` |
| 导航栏底部分隔线 | `Rectangle` 高 1，`Colors.grayColor.opacity(0.3)` |
| 系统导航栏 | `.navigationBarHidden(true)` |
| 表单卡片 | 背景 `Colors.whiteColor`，圆角 `Dimens.borderRadius`(10) |
| 卡片外边距 | `.padding(.horizontal, Dimens.middleMargin)` + `.padding(.top, Dimens.middleMargin)` |
| 表单行内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 标签与内容间距 | `Dimens.middleMargin` |
| 标签列宽 | 固定 `80`（写死值，非 `Dimens` 常量） |
| 必填星号 | `Text("*")`，`Colors.warnColor`，与标签间距 `2` |
| 行分割线 | 高 1，`Colors.grayColor.opacity(0.3)`，左缩进 `Dimens.middleMargin` |
| 输入文字 | `Dimens.normalFont`(17) |
| 行内错误文案 | `Dimens.normalFont - 2`(15)，`Colors.warnColor` |
| 错误文案与输入框间距 | `Dimens.smallIcon`(15)（用图标常量当间距，见 §10） |
| 确定按钮 | 高 `Dimens.btnHeight`(50)，圆角 `Dimens.btnHeight / 2`，可用 `Colors.primaryColor` / 禁用 `Colors.grayColor`，文字 `Colors.whiteColor` |
| 按钮内 loading | `ProgressView` tint `.white`（**未设 frame**） |
| 卡片与按钮间距 | `Dimens.middleMargin`（外层 VStack spacing） |

## 9. 交互流程

```
1. ForgetPasswordPage 发送验证码成功 → 1.5s 后 push ResetPasswordPage(email: <用户填的邮箱>)
2. 用户从邮箱抄验证码，填「新密码」「确认密码」「验证码」
     每次输入 → body 重算 isPasswordMatch / isFormValid
       两次密码不一致且确认密码非空 → 行内红字「两次输入的密码不一致」
       任一为空或不一致 → 确定按钮 grayColor + disabled
3. 点「确定」→ handleResetPassword()
     ├─ !isPasswordMatch          → alert「两次输入的密码不一致」并 return
     ├─ newPassword.count < 6     → alert「密码长度不能少于6位」并 return
     ├─ isResetting = true（按钮「重置中...」+ 转圈 + 禁用）
     └─ POST /service/user/resetPassword { email, password: md5, code }
          ├─ SUCCESS 且 data + token 齐备
          │    → appState.updateUserData(userData)
          │    → appState.updateToken(token)  →  TokenManager.saveToken + isLoggedIn = true
          │    → navigateToCompanyPage = true → fullScreenCover: CompanyPage（选公司）
          └─ FAIL / 验证码错误 / 网络错误
               → alert(error.localizedDescription)
               → 停留本页，输入保留（但无法重发验证码，只能返回上一页重来）
4. 或点导航栏返回 → dismiss() → 回到 ForgetPasswordPage
```

边界条件：

- **验证码过期/错误**：由后端判定，客户端只能拿到 `msg` 弹窗；用户想换一个验证码必须**返回上一页重新提交邮箱**。
- **邮箱不可改**：`email` 是 `let` 构造参数，写错邮箱只能返回上一页。
- **重置即登录**：成功后 `isLoggedIn = true`、token 落 `UserDefaults`（key `auth_token`），下次冷启动 [WelcomePage](WelcomePage.md) 的 `getUserData` 会直接通过。
- **不做角色/权限判断**：本页与 `Company.role` / `Tenant.role` 无关。

## 10. 二次开发指引

- **改文案 / 样式**：标题在 `customNavigationBar`；三个字段标签与占位在 `body` 的 `formRow(...)` 调用处；按钮文案在确定 `Button` 的 `Text(isResetting ? ... : ...)`；行样式改 `formRow`，分割线改 `DividerLine()`。
- **加「重新发送验证码」**：需要 ① 在页面加 `countdown` / `timer` / `isSendingCode` 三个 `@State` ② 调
  `HTTPClient.shared.sendEmailVertifyCode(email: email)`（已有方法，见 [ForgetPasswordPage](ForgetPasswordPage.md) §6.1）
  ③ 参考 [LoginPage](LoginPage.md) 的 `startCountdown()` 实现倒计时并在 `onDisappear` 里 `invalidate`。
- **加密码强度规则**：改 `handleResetPassword()` 里的 `newPassword.count < 6` 分支，或把规则提到 `isFormValid` 让按钮提前置灰（建议同步给 [RegisterPage](RegisterPage.md)，它目前**没有**长度校验）。
- **加字段**：`Models/User.swift`（含 `CodingKeys`）→ `HTTPClient.resetPassword` 的 `parameters` → 页面 `@State` → `body` 的 `formRow` → 后端 `ResetPasswordConfirm` 实体 + `docs/api/user.md`。
- **加接口**：`Constants.API` → `APIEndpoints.swift` 的 `case` + `path` 分支 + `method` 分支（三处，`method` 是穷举 `switch`）→ `HTTPClient` 方法 → 页面调用。

### 已知坑 / 注意事项

1. **没有重发验证码入口**：验证码过期或没收到时，用户必须点返回回到 [ForgetPasswordPage](ForgetPasswordPage.md) 再提交一次邮箱，体验断裂。
2. **页面不显示目标邮箱**：`email` 只用于请求，界面上完全不可见，用户无法确认验证码是发到了哪个邮箱。
3. **6 位长度校验只在提交时生效**：`isFormValid` 不含长度判断，所以密码填 1 位按钮也是亮的，点下去才弹 alert。应把 `newPassword.count >= 6` 并入 `isFormValid`。
4. **与 [RegisterPage](RegisterPage.md) 的密码规则不一致**：注册页对密码**只校验两次一致 + 非空**，本页要求至少 6 位。会出现「注册时设的 3 位密码，重置时不许再设 3 位」的割裂。
5. **验证码无格式校验**：`keyboardType(.numberPad)` 只是键盘提示，代码层面只判 `!verificationCode.isEmpty`，1 位也能提交（外接键盘/粘贴还能输入非数字）。
6. **`.navigationBarHidden(true)` 已被弃用**：iOS 16+ 推荐 `.toolbar(.hidden, for: .navigationBar)`。当前能用，升级 SDK 时会有弃用警告。
7. **混合导航链路**：本页是被 `navigationDestination` **push** 出来的，却用 `fullScreenCover` 弹 `CompanyPage`。`CompanyPage` 之下仍残留 `ForgetPasswordPage` + `ResetPasswordPage` 的导航栈（`ForgetPasswordPage` 本身又在 `LoginPage` 的 `fullScreenCover` 里），层级很深；`CompanyPage` 若被 dismiss 会回到重置密码页而不是首页。
8. **不显式 `saveToken`**：token 落地依赖 ① `HTTPClient.request` 解码到 `token` 时的自动保存 ② `AppState.updateToken` 内部的 `saveToken`。与 [LoginPage](LoginPage.md) 的显式三连写法不一致，改 `AppState.updateToken` 时本页会静默失去 token。
9. **成功后不置 `appState.isLoggedIn`**：页面只调 `updateUserData` + `updateToken`，靠 `updateToken` 内部把 `isLoggedIn` 置真（[LoginPage](LoginPage.md) 是显式再赋一次）。若 `updateToken` 实现变更，本页登录态会失效。
10. **`DividerLine()` 命名不符 Swift 规范**：`private func` 用了大驼峰（像类型名），与 [RegisterPage](RegisterPage.md) 同款问题。
11. **`Dimens.smallIcon` 被当作间距使用**：确认密码行 `VStack(spacing: Dimens.smallIcon)` 与按钮 `HStack(spacing: Dimens.smallIcon)`，不符合「所有间距统一用 `Dimens.middleMargin`」的样式铁律。
12. **标签列宽写死 `80`**：`formRow` 的 `.frame(width: 80, alignment: .leading)` 是魔法数字；且 [ForgetPasswordPage](ForgetPasswordPage.md) 的同名方法没有这一行，三份 `formRow` 实现各自独立拷贝。
13. **`appState` 只写不读**：`@ObservedObject` 声明带来了不必要的视图订阅刷新，本页并未展示任何 `AppState` 数据。
14. **`ProgressView` 未限制尺寸**：按钮内的 `ProgressView` 没有 `.frame(...)`。
15. **后端文档出参示例与客户端解码要求冲突**：见 §6.1 末尾提示。

## 相关文档

- [ForgetPasswordPage](ForgetPasswordPage.md) —— 本页的上一步（传入 `email`）
- [LoginPage](LoginPage.md) —— 整条找回链路的起点
- [RegisterPage](RegisterPage.md)、[WelcomePage](WelcomePage.md)
