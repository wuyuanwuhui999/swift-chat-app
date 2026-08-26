---
name: login-page
description: 登录页（账号密码 / 邮箱验证码双 Tab）。当你需要改登录方式、验证码倒计时、登录后 token 落地流程，或排查「登录成功却没跳转」问题时读这份文档。
page: LoginPage.swift
path: chat/chat/UI/Pages/LoginPage.swift
apis:
  - POST /service/user/login
  - POST /service/user/sendEmailVertifyCode
  - POST /service/user/loginByEmail
---

# LoginPage（登录页）

## 1. 页面职责

面向未登录用户的统一登录入口，提供两种登录方式：**账号密码登录**（Tab 0）与**邮箱验证码登录**（Tab 1），由顶部 Tab 切换。

登录成功后负责把 token 落到 `TokenManager`、把用户信息与 token 灌进 `AppState`，再全屏推进 `CompanyPage` 选择公司。

同时它还是注册与找回密码的入口（页面底部两个按钮）。在业务链路上位于 `WelcomePage` 之后、`CompanyPage` 之前，是所有鉴权态的起点。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/LoginPage.swift`（约 380 行，含 `#Preview`）
- **入口**：[WelcomePage](WelcomePage.md) 在无 token 或 `getUserData` 失败时用 `fullScreenCover` 弹出
- **出口**（全部为 `fullScreenCover`）：
  - `RegisterPage`（`showRegisterPage`）
  - `ForgetPasswordPage`（`showForgetPasswordPage`）
  - `CompanyPage`（`navigateToCompanyPage`，两种登录方式成功后共用）
- **依赖组件**：
  - `UI/Components/AIAvatar.swift` —— `AIAvatar.large()` 顶部 Logo
  - `UI/Components/CustomTextField.swift` —— 账号 / 密码输入框（`text` / `placeholder` / `isSecure`）
  - 邮箱与验证码输入框是**页内手写**的 `TextField`，未复用 `CustomTextField`
- **依赖模型**：`Models/User.swift`、`Models/BaseResponse.swift`、`Models/AppState.swift`、`LoginResponse`（定义在 `HTTPClient.swift` 第 1608 行）
- **依赖服务**：
  - `HTTPClient.shared.login(userAccount:password:completion:)`
  - `HTTPClient.shared.sendEmailVerificationCode(email:completion:)`
  - `HTTPClient.shared.loginByEmail(email:code:completion:)`
  - `TokenManager.shared.saveToken(_:)` / `getToken()`
  - `AppState.shared.updateUserData(_:)` / `updateToken(_:)` / `isLoggedIn`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState`（`@ObservedObject private`） | `AppState` | `AppState.shared` | 全局状态；登录成功后写入用户信息与 token |
| `selectedTab`（`@State private`） | `Int` | `0` | `0` 账号密码登录 / `1` 邮箱验证码登录 |
| `navigateToCompanyPage`（`@State private`） | `Bool` | `false` | 控制 `CompanyPage` 的 `fullScreenCover` |
| `account`（`@State private`） | `String` | `"吴时吴刻"` | 账号输入（**硬编码调试默认值**，见 §10） |
| `password`（`@State private`） | `String` | `"123456"` | 密码输入（**硬编码调试默认值**） |
| `isLoggingIn`（`@State private`） | `Bool` | `false` | 登录中；控制按钮 `ProgressView` 与 `disabled` |
| `email`（`@State private`） | `String` | `""` | 邮箱输入 |
| `verificationCode`（`@State private`） | `String` | `""` | 验证码输入 |
| `isSendingCode`（`@State private`） | `Bool` | `false` | 验证码发送中；仅用于禁用发送按钮 |
| `isEmailValid`（`@State private`） | `Bool` | `false` | 邮箱正则校验结果 |
| `countdown`（`@State private`） | `Int` | `0` | 重发倒计时秒数（60 → 0） |
| `timer`（`@State private`） | `Timer?` | `nil` | 倒计时定时器句柄 |
| `showAlert`（`@State private`） | `Bool` | `false` | 通用提示弹窗开关 |
| `alertMessage`（`@State private`） | `String` | `""` | 弹窗文案 |
| `showRegisterPage`（`@State private`） | `Bool` | `false` | 控制 `RegisterPage` |
| `showForgetPasswordPage`（`@State private`） | `Bool` | `false` | 控制 `ForgetPasswordPage` |

计算属性（非 `private`）：

| 属性 | 类型 | 规则 |
|---|---|---|
| `isLoginButtonEnabled` | `Bool` | `selectedTab == 0` 时 `!account.isEmpty && !password.isEmpty`；否则 `isEmailValid && !verificationCode.isEmpty` |

无 `@StateObject` / `@Binding` / `@Environment`（本页不用 `dismiss`，因为它是被 `fullScreenCover` 弹出的根级页面）。

## 4. 视图结构

```
body: ZStack
├─ Colors.pageBackgroundColor.ignoresSafeArea()
└─ VStack
   ├─ Spacer()
   ├─ AIAvatar.large()                                  80x80 方形 Logo
   ├─ Spacer().frame(height: Dimens.middleMargin)        固定 15pt 间隔
   ├─ 登录卡片 VStack(spacing: Dimens.middleMargin)
   │  │   .padding(Dimens.middleMargin)
   │  │   .background(Color.themeWhite) .cornerRadius(Dimens.borderRadius)
   │  │   .padding(.horizontal, Dimens.middleMargin)
   │  ├─ Tab 切换 HStack(spacing: 0)
   │  │  ├─ Button「账号密码登录」 VStack(spacing: middleMargin/2)
   │  │  │     Text 字号 normalFont，选中 primaryColor / 未选中 blackColor
   │  │  │     Rectangle 下划线 高 2，选中 primaryColor / 未选中 Color.clear
   │  │  │     .frame(maxWidth: .infinity)
   │  │  └─ Button「邮箱验证码登录」（同上结构）
   │  │     两个 Button 点击都包在 withAnimation { selectedTab = ... }
   │  ├─ if selectedTab == 0 → 账号密码面板 VStack(spacing: middleMargin)
   │  │  ├─ CustomTextField(text: $account,  placeholder: "请输入账号", isSecure: false)
   │  │  └─ CustomTextField(text: $password, placeholder: "请输入密码", isSecure: true)
   │  ├─ else → 邮箱验证码面板 VStack(spacing: middleMargin)
   │  │  ├─ ZStack(alignment: .trailing) 邮箱输入
   │  │  │  ├─ TextField prompt「请输入邮箱」 灰色占位
   │  │  │  │     keyboardType .emailAddress / autocapitalization .none
   │  │  │  │     .onChange(of: email) { validateEmail() }
   │  │  │  │     高 Dimens.inputHeight，白底，圆角 inputHeight/2 描边 grayColor 1px
   │  │  │  │     右侧留白 padding(.trailing, inputHeight + middleMargin)
   │  │  │  └─ Button(sendVerificationCode) 图标 paperplane.fill
   │  │  │        大小 Dimens.smallIcon(15)，点击区 inputHeight x inputHeight
   │  │  │        可用色 primaryColor / 不可用 grayColor
   │  │  │        .disabled(!isEmailValid || isSendingCode || countdown > 0)
   │  │  └─ ZStack(alignment: .trailing) 验证码输入
   │  │     ├─ TextField prompt「请输入验证码」 keyboardType .numberPad
   │  │     │     右侧留白随 countdown 动态变化
   │  │     └─ if countdown > 0 → Text("\(countdown)s") 灰色，占位 inputHeight 宽
   │  ├─ Button(handleLogin) 登录
   │  │     HStack(spacing: Dimens.smallIcon)：isLoggingIn 时 ProgressView(tint: .themeWhite) 15x15
   │  │     文案 isLoggingIn ? "" : "登录"，白字
   │  │     高 Dimens.btnHeight，底色 isLoginButtonEnabled ? primaryColor : grayColor
   │  │     .cornerRadius(Dimens.btnHeight)   ← 注意不是 btnHeight/2
   │  │     .disabled(!isLoginButtonEnabled || isLoggingIn)
   │  ├─ Button(handleRegister) 注册
   │  │     文字 .themeGray，透明底，overlay RoundedRectangle(cornerRadius: btnHeight) 描边 grayColor
   │  └─ Button(handleForgotPassword)「忘记密码？」
   │        .themeGray + .underline()，PlainButtonStyle
   └─ Spacer() + Spacer()                                （连续两个，把卡片整体上移）

修饰器（挂在 ZStack 上）
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) } message: { Text(alertMessage) }
├─ .fullScreenCover(isPresented: $showRegisterPage)       { RegisterPage() }
├─ .fullScreenCover(isPresented: $showForgetPasswordPage) { ForgetPasswordPage() }
├─ .fullScreenCover(isPresented: $navigateToCompanyPage)  { CompanyPage() }
└─ .onDisappear { timer?.invalidate(); timer = nil }
```

`CustomTextField` 内部样式：高 `Dimens.inputHeight`、白底、圆角 `inputHeight / 2`，
描边聚焦时 `Colors.primaryColor`、非聚焦 `Colors.grayColor`（`@FocusState` 驱动）。

## 5. 核心方法

### `validateEmail()`
- **触发**：邮箱 `TextField` 的 `.onChange(of: email)`
- **步骤**：
  1. 正则 `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}`
  2. `NSPredicate(format: "SELF MATCHES %@")` 求值，结果写入 `isEmailValid`
- **失败处理**：无提示文案，只让发送按钮与登录按钮置灰

### `sendVerificationCode()`
- **触发**：邮箱输入框内 `paperplane.fill` 按钮点击
- **步骤**：
  1. `guard isEmailValid else { return }`（双保险，按钮本身也已 `disabled`）
  2. `isSendingCode = true`
  3. 调 `HTTPClient.shared.sendEmailVerificationCode(email: email)`，回调切主线程后 `isSendingCode = false`
  4. `.success(let response)`：`alertMessage = response.msg ?? "验证码已发送"`，`showAlert = true`；
     **仅当 `response.isSuccess` 为真**才 `startCountdown()`
  5. `.failure(let error)`：`alertMessage = error.localizedDescription`，`showAlert = true`
- **失败处理**：弹 `alert`，不启动倒计时，用户可立即重试

> 注意：这里 `.success` 分支**无论后端 `status` 是 SUCCESS 还是 FAIL 都会弹窗**，因为
> `sendEmailVerificationCode` 把整个 `BaseResponse<EmptyData>` 原样透传给了页面（不像其它方法会把 FAIL 转成 `.failure`）。

### `startCountdown()`
- **触发**：`sendVerificationCode()` 成功后
- **步骤**：
  1. `countdown = 60`
  2. `Timer.scheduledTimer(withTimeInterval: 1, repeats: true)`，回调内 `DispatchQueue.main.async`
  3. `countdown > 0` 时自减；归零后 `timer?.invalidate()` + `timer = nil`
- **清理**：`.onDisappear` 也会 `invalidate`

### `handleLogin()`
- **触发**：登录按钮点击
- **步骤**：按 `selectedTab` 分发到 `handlePasswordLogin()`（0）或 `handleEmailLogin()`（1）

### `handlePasswordLogin()`
- **触发**：`handleLogin()` 分发
- **步骤**：
  1. `isLoggingIn = true`
  2. `HTTPClient.shared.login(userAccount: account, password: password)`（**密码在 HTTPClient 内部做 `md5`**）
  3. 回调切主线程 → `isLoggingIn = false`
  4. `.success(let loginResponse)`：
     1. `TokenManager.shared.saveToken(loginResponse.token)`
     2. `appState.updateUserData(loginResponse.userData)`
     3. `appState.updateToken(loginResponse.token)`（内部又会 `saveToken` 并置 `isLoggedIn = true`）
     4. `appState.isLoggedIn = true`
     5. `TokenManager.shared.getToken()` 回读校验，只 `print` ✅/❌
     6. `navigateToCompanyPage = true`
  5. `.failure(let error)`：`alertMessage = error.localizedDescription` + `showAlert = true`
- **失败处理**：弹 `alert`，输入框内容保留

### `handleEmailLogin()`
- **触发**：`handleLogin()` 分发
- **步骤**：与 `handlePasswordLogin()` 完全同构，只把请求换成
  `HTTPClient.shared.loginByEmail(email: email, code: verificationCode)`
- **失败处理**：同上

### `handleRegister()` / `handleForgotPassword()`
- **触发**：底部「注册」/「忘记密码？」按钮
- **步骤**：分别置 `showRegisterPage = true` / `showForgetPasswordPage = true`

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `login` | POST | `/service/user/login` | Tab 0 点「登录」 | `docs/api/user.md` §2 |
| 2 | `sendEmailVerificationCode` | POST | `/service/user/sendEmailVertifyCode` | Tab 1 点发送图标 | `docs/api/user.md` §6 |
| 3 | `loginByEmail` | POST | `/service/user/loginByEmail` | Tab 1 点「登录」 | `docs/api/user.md` §8 |

三个接口都在后端**鉴权白名单**内（无需 token）。

### 6.1 `login`

- **Swift 签名**：`func login(userAccount: String, password: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void)`（`HTTPClient.swift` 第 231 行）
- **APIEndpoint**：`.login` → `Constants.API.login = "/service/user/login"`，method `"POST"`
- **请求**（JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `userAccount` | Body | String | 是 | 账号，直传 `account` |
| `password` | Body | String | 是 | `password.md5`（`HTTPClient` 内 `let encryptedPassword = password.md5`，CommonCrypto `CC_MD5`） |

- **响应**：`BaseResponse<User>`。客户端判定成功的条件是
  `response.isSuccess && response.data != nil && response.token != nil`，三者齐备才组装
  `LoginResponse(userData:token:)`；否则转 `NetworkError.custom(message: response.msg ?? "登录失败")`。
- **UI 处理**：成功 → 见 `handlePasswordLogin()` 步骤 4；失败 → `alert` 显示 `error.localizedDescription`。

### 6.2 `sendEmailVerificationCode`

- **Swift 签名**：`func sendEmailVerificationCode(email: String, completion: @escaping (Result<BaseResponse<EmptyData>, NetworkError>) -> Void)`（`HTTPClient.swift` 第 274 行）
- **APIEndpoint**：`.sendEmailVertifyCode` → `Constants.API.sendEmailVertifyCode = "/service/user/sendEmailVertifyCode"`，method `"POST"`
  （**注意后端与客户端的路径拼写都是 `Vertify` 而不是 `Verify`**，Swift 方法名却是 `Verification`）
- **请求**（JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `email` | Body | String | 是 | 收件邮箱（后端实体 `MailRequest`） |

- **响应**：`BaseResponse<EmptyData>`，后端文档 §6 出参 `data` 为 `null`。**整个 response 原样回传给页面**，不做 `isSuccess` 转换。
- **UI 处理**：`isSuccess` 为真 → 启动 60s 倒计时；无论真假都弹 `alert`（文案优先用后端 `msg`）。

### 6.3 `loginByEmail`

- **Swift 签名**：`func loginByEmail(email: String, code: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void)`（`HTTPClient.swift` 第 290 行）
- **APIEndpoint**：`.loginByEmail` → `Constants.API.loginByEmail = "/service/user/loginByEmail"`，method `"POST"`
- **请求**（JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `email` | Body | String | 是 | 邮箱 |
| `code` | Body | String | 是 | 邮箱验证码，**不做本地格式/长度校验**，只校验非空 |

- **响应**：`BaseResponse<User>`，成功判定与 `login` 完全一致，失败文案默认「登录失败」。
- **UI 处理**：与 `handlePasswordLogin()` 一致。

> **与后端文档的差异**：`docs/api/user.md` 中 login / loginByEmail 的出参示例里 `data` 为 `null`、只有 `token`。
> 而客户端**要求 `data` 必须能解码成 `User`**，否则判失败。若后端确实只回 token，账号密码登录会在
> 客户端被误判为「登录失败」。以后端实际返回为准，文档示例可能是简化写法。

## 7. 数据模型

- `LoginResponse`（`HTTPClient.swift` 第 1608 行，**非 Codable，纯本地组装体**）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `userData` | `User` | 由 `BaseResponse.data` 解出 |
| `token` | `String` | 由 `BaseResponse.token` 解出 |

- `User`（`Models/User.swift`）本页只做整体传递，不读取单个字段。关键点：`userAccount` / `username` / `telephone` / `email` / `sex` / `sign` 非可选，`id` / `avater` / `birthday` / `role` / `password` / `region` / `disabled` / `permission` 可选。
- `EmptyData`（`Models/BaseResponse.swift` 第 46 行）：空结构体，用于 `data` 为 null 的响应。
- `BaseResponse<T>`：`data` / `token` / `status` / `msg` / `total` + `isSuccess`。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` + `.ignoresSafeArea()` |
| 顶部 Logo | `AIAvatar.large()`（`Dimens.bigAvater` = 80，方形） |
| Logo 与卡片间距 | `Spacer().frame(height: Dimens.middleMargin)` |
| 登录卡片背景 | `Color.themeWhite`（= `Colors.whiteColor`） |
| 卡片圆角 | `Dimens.borderRadius`(10) |
| 卡片内边距 / 外边距 | `Dimens.middleMargin`(15) |
| 卡片内元素间距 | `Dimens.middleMargin` |
| Tab 文字 | `Dimens.normalFont`(17)；选中 `Colors.primaryColor`，未选中 `Colors.blackColor` |
| Tab 下划线 | `Rectangle` 高 2；选中 `Colors.primaryColor`，未选中 `Color.clear` |
| Tab 内间距 | `Dimens.middleMargin / 2` |
| 输入框高度 / 圆角 | `Dimens.inputHeight`(50) / `Dimens.inputHeight / 2` |
| 输入框描边 | `Colors.grayColor` 1px（`CustomTextField` 聚焦时变 `Colors.primaryColor`） |
| 输入框文字 | `Dimens.normalFont`，`.black`；占位 `.gray` |
| 发送验证码图标 | `paperplane.fill`，`Dimens.smallIcon`(15)；可用 `Colors.primaryColor` / 不可用 `Colors.grayColor` |
| 倒计时文字 | `Dimens.normalFont`，`Colors.grayColor` |
| 登录按钮 | 高 `Dimens.btnHeight`(50)，圆角 `Dimens.btnHeight`，可用 `Colors.primaryColor` / 禁用 `Colors.grayColor`，文字 `.themeWhite` |
| 注册按钮 | 高 `Dimens.btnHeight`，透明底，描边 + 文字 `Colors.grayColor`，圆角 `Dimens.btnHeight` |
| 忘记密码 | `Dimens.normalFont`，`.themeGray`，`.underline()` |
| 按钮内 loading | `ProgressView` tint `.themeWhite`，`Dimens.smallIcon` |

## 9. 交互流程

**账号密码登录**

```
1. WelcomePage 无有效 token → fullScreenCover 弹出 LoginPage
2. selectedTab 默认 0，account/password 已预填调试值 → isLoginButtonEnabled = true
3. 点「登录」→ isLoggingIn = true（按钮文案清空、显示 ProgressView、禁用）
4. POST /service/user/login  { userAccount, password: md5 }
5. SUCCESS 且 data + token 齐备
     → TokenManager.saveToken
     → AppState.updateUserData / updateToken / isLoggedIn = true
     → navigateToCompanyPage = true → fullScreenCover: CompanyPage
6. FAIL / 网络错误 → alert(error.localizedDescription)，停留本页
```

**邮箱验证码登录**

```
1. 点 Tab「邮箱验证码登录」→ withAnimation { selectedTab = 1 }
2. 输入邮箱 → onChange → validateEmail() → isEmailValid
     isEmailValid == false 时发送图标灰色且 disabled
3. 点 paperplane → POST /service/user/sendEmailVertifyCode { email }
     → alert 提示（文案取后端 msg）
     → isSuccess 时 countdown = 60，Timer 每秒自减，验证码框右侧显示 "60s"…"1s"
     → countdown > 0 期间发送按钮 disabled
4. 输入验证码 → isLoginButtonEnabled = isEmailValid && !verificationCode.isEmpty
5. 点「登录」→ POST /service/user/loginByEmail { email, code }
6. 成功/失败分支与账号密码登录完全一致
```

**分支出口**

```
「注册」        → showRegisterPage       → fullScreenCover: RegisterPage
「忘记密码？」  → showForgetPasswordPage → fullScreenCover: ForgetPasswordPage
```

边界条件：

- 登录中（`isLoggingIn`）按钮被 `disabled`，可防重复提交；但**发送验证码没有请求级去重**，只靠 `isSendingCode` + `countdown`。
- Tab 切换**不清空**另一侧的输入，也不重置 `countdown` / `timer`。
- 页面消失（`onDisappear`）才会销毁 `Timer`。

## 10. 二次开发指引

- **改文案 / 样式**：全部集中在 `body` 内，没有抽子视图。Tab 文案在 Tab 切换 `HStack` 的两个 `Button` 里；按钮样式在对应 `Button` 的 `.background` / `.overlay` 处。
- **加第三种登录方式**：需要同时改 ① `selectedTab` 的取值语义（目前是裸 `Int`，建议改枚举）② `isLoginButtonEnabled` 的 `if/else` ③ 面板的 `if selectedTab == 0 { } else { }` ④ `handleLogin()` 的分发。
- **加字段**（如登录返回新增业务字段）：`Models/User.swift`（含 `CodingKeys`）→ `HTTPClient.login` 的成功分支 → `AppState` → 页面。
- **加接口**：`Constants.API` 加常量 → `APIEndpoints.swift` 加 `case` + `path` 分支 + `method` 分支（三处，`method` 是穷举 `switch`）→ `HTTPClient` 写业务方法 → 页面调用。
- **抽复用**：邮箱与验证码输入框是页内手写的，`ForgetPasswordPage` / `ResetPasswordPage` 又各写了一套 `formRow`，如需统一建议抽到 `UI/Components`。

### 已知坑 / 注意事项

1. **硬编码调试账号**：`account = "吴时吴刻"`、`password = "123456"` 是写死的初值，**上线前必须清空**，否则任何用户打开 App 都能看到这组凭证。
2. **登录按钮圆角写法不符规范**：项目样式铁律要求按钮圆角 `Dimens.btnHeight / 2`，这里登录/注册按钮都写的是 `cornerRadius(Dimens.btnHeight)`（50）。视觉上仍是胶囊（因为高度也是 50，圆角会被截断），但与规范和其它页面写法不一致。
3. **登录中按钮文案变空串**：`Text(isLoggingIn ? "" : "登录")`，加载态只有一个转圈，没有「登录中…」文案（`RegisterPage` / `ResetPasswordPage` 都写了文案）。
4. **同一 `ZStack` 上挂了三个 `fullScreenCover`**：`RegisterPage` / `ForgetPasswordPage` / `CompanyPage`。SwiftUI 对同视图多个同类 presentation 修饰器支持不可靠，目前靠"三个状态互斥"侥幸正常。新增第四个或出现同时为 `true` 的场景就会失效，建议改成枚举 + `fullScreenCover(item:)`。
5. **`sendEmailVerificationCode` 失败也弹"成功"文案的风险**：`.success` 分支里 `alertMessage = response.msg ?? "验证码已发送"`。若后端返回 `status = "FAIL"` 但 `msg` 为 `null`，用户会看到「验证码已发送」而实际没发出去（倒计时不会启动，是唯一区分线索）。
6. **`isSendingCode` 未用于 UI 反馈**：只参与 `disabled` 判断，发送按钮不显示 loading。
7. **Tab 切换不重置状态**：切到账号密码 Tab 后 `timer` 仍在跑、`countdown` 仍在减；切回来时倒计时会"跳秒"。
8. **`onDisappear` 清理不可靠**：本页是被 `fullScreenCover` 弹出的，`CompanyPage` 再以 `fullScreenCover` 盖在它上面时 `LoginPage` 不一定触发 `onDisappear`，`Timer` 可能继续持有强引用。
9. **`appState.updateToken` 与 `TokenManager.saveToken` 重复调用**：`updateToken` 内部已经 `TokenManager.shared.saveToken(token)` 并置 `isLoggedIn = true`；页面又手动 `saveToken` + `isLoggedIn = true`。此外 `HTTPClient.request` 在解码到 `token` 时**也会**保存一次，同一 token 实际写了三遍。
10. **回读校验只打日志**：`if let _ = TokenManager.shared.getToken()` 的 ✅/❌ 只 `print`，失败时不阻止跳转。
11. **验证码无长度/格式校验**：`isLoginButtonEnabled` 只判 `!verificationCode.isEmpty`，输入 1 位也能提交。
12. **账号密码无长度校验**：同样只判非空，`RegisterPage` 有 6 位密码校验、`ResetPasswordPage` 有 6 位校验，登录页没有。
13. **邮箱正则写在两处**：`LoginPage.validateEmail()` 与 [ForgetPasswordPage](ForgetPasswordPage.md) 的 `isEmailValid` 用的是同一段正则字符串，各自拷贝了一份（`RegisterPage.validateEmail()` 是第三份）。
14. **接口名拼写**：路径与后端一致为 `sendEmailVertifyCode`（`Vertify`），Swift 方法名为 `sendEmailVerificationCode`。改名时两端要一起动。

## 相关文档

- [WelcomePage](WelcomePage.md) —— 本页的入口
- [RegisterPage](RegisterPage.md)
- [ForgetPasswordPage](ForgetPasswordPage.md) → [ResetPasswordPage](ResetPasswordPage.md)
