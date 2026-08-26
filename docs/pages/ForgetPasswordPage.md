---
name: forget-password-page
description: 忘记密码页（输入注册邮箱 → 发验证码 → 跳重置密码）。当你需要改找回密码入口、验证码发送逻辑，或排查「提交后没跳到重置页」问题时读这份文档。
page: ForgetPasswordPage.swift
path: chat/chat/UI/Pages/ForgetPasswordPage.swift
apis:
  - POST /service/user/sendEmailVertifyCode
---

# ForgetPasswordPage（忘记密码页）

## 1. 页面职责

密码找回链路的**第一步**：让用户填写注册时用的邮箱，向该邮箱发送验证码，然后把邮箱透传给下一步的 [ResetPasswordPage](ResetPasswordPage.md) 完成密码重置。

页面只有一个输入项（邮箱）和一个提交按钮，本地做邮箱正则校验，校验不过按钮保持灰色禁用。

它是全链路里唯一自带 `NavigationStack` 的认证页，因为需要用 `navigationDestination` 向前推进 `ResetPasswordPage`。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/ForgetPasswordPage.swift`（约 180 行，含 `#Preview`）
- **入口**：[LoginPage](LoginPage.md) 底部「忘记密码？」按钮 → `handleForgotPassword()` → `showForgetPasswordPage = true` → `fullScreenCover`
- **出口**：
  - `ResetPasswordPage(email: email)`（`navigationDestination(isPresented: $navigateToReset)`，**push 而非 cover**）
  - 返回 `LoginPage`：导航栏左侧 `chevron.left` → `@Environment(\.dismiss)`
- **依赖组件**：**无外部组件**。导航栏与表单行都是页内私有实现
  （`customNavigationBar`、`formRow(label:isRequired:content:)`）；本页**没有** `DividerLine()`（只有一行表单）
- **依赖模型**：`Models/BaseResponse.swift`（`BaseResponse<EmptyData>`）
- **依赖服务**：`HTTPClient.shared.sendEmailVerificationCode(email:completion:)`
- **不依赖** `AppState` / `TokenManager`（本页不涉及登录态）

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `dismiss`（`@Environment(\.dismiss) private`） | `DismissAction` | — | 导航栏返回按钮关闭本页 |
| `email`（`@State private`） | `String` | `""` | 邮箱输入 |
| `isSending`（`@State private`） | `Bool` | `false` | 发送中；按钮显示 `ProgressView` + 文案「发送中...」并禁用 |
| `showAlert`（`@State private`） | `Bool` | `false` | 通用提示弹窗开关 |
| `alertMessage`（`@State private`） | `String` | `""` | 弹窗文案 |
| `navigateToReset`（`@State private`） | `Bool` | `false` | 驱动 `navigationDestination` 推进 `ResetPasswordPage` |

计算属性：

| 属性 | 类型 | 规则 |
|---|---|---|
| `isEmailValid`（`private var`） | `Bool` | 每次求值都新建 `NSPredicate`，正则 `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}` |

无 `@ObservedObject` / `@StateObject` / `@Binding`。

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   │   .background(Colors.pageBackgroundColor)
   ├─ customNavigationBar                             白底 + 底部 1px 分隔线
   └─ ScrollView                                      背景 Colors.pageBackgroundColor
      └─ VStack(spacing: Dimens.middleMargin)
         │   .padding(.horizontal, Dimens.middleMargin) .padding(.top, Dimens.middleMargin)
         ├─ 表单卡片 VStack(spacing: 0)
         │  │   .background(Colors.whiteColor) .cornerRadius(Dimens.borderRadius)
         │  └─ formRow「邮箱」*  TextField「请输入注册邮箱」
         │        字号 Dimens.normalFont
         │        .autocapitalization(.none) / .keyboardType(.emailAddress)
         └─ Button(handleSubmit) 提交
               HStack(spacing: Dimens.smallIcon)：isSending → ProgressView(tint: .white)
               文案 isSending ? "发送中..." : "提交"，色 Colors.whiteColor
               高 Dimens.btnHeight，底 (isEmailValid && !isSending) ? primaryColor : grayColor
               圆角 Dimens.btnHeight / 2
               .disabled(!isEmailValid || isSending)
               .padding(.bottom, Dimens.middleMargin)

修饰器（挂在 NavigationStack 内层 VStack 上）
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) } message: { Text(alertMessage) }
└─ .navigationDestination(isPresented: $navigateToReset) { ResetPasswordPage(email: email) }
```

**子视图 / 私有构建器**

```
customNavigationBar: HStack
├─ Button(dismiss) chevron.left  字号 Dimens.middleIcon(30)，色 Colors.subColor
├─ Spacer()
├─ Text「忘记密码」              字号 Dimens.middleFont(20)，色 .black
├─ Spacer()
└─ Button 占位（chevron.left 透明色，disabled(true)）—— 保持标题居中
   .padding(.horizontal/.vertical, Dimens.middleMargin) .background(Colors.whiteColor)
   .overlay(Rectangle().fill(Colors.grayColor.opacity(0.3)).frame(height: 1), alignment: .bottom)

formRow(label:isRequired:content:): HStack(alignment: .center, spacing: Dimens.middleMargin)
├─ 标签 HStack(spacing: 2)：isRequired 时前置 Text("*") 色 Colors.warnColor
│     Text(label) 字号 normalFont 黑色
│     ← 注意：本页 formRow 没有 .frame(width: 80)（与 RegisterPage / ResetPasswordPage 不同）
└─ content.frame(maxWidth: .infinity, alignment: .leading)
   .padding(.horizontal/.vertical, Dimens.middleMargin)
```

> 表单卡片虽然只有一行，仍保留了 `VStack(spacing: 0)` 的多行结构骨架，方便后续追加字段。

## 5. 核心方法

### `isEmailValid`（计算属性）
- **签名**：`private var isEmailValid: Bool`
- **触发**：`body` 每次求值（按钮底色 + `disabled` 都读它），**输入每变一个字符就重算一次**
- **步骤**：
  1. 正则字符串 `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}`
  2. `NSPredicate(format: "SELF MATCHES %@", emailRegex)`
  3. `emailPredicate.evaluate(with: email)`
- **注意**：与 [LoginPage](LoginPage.md) 不同，这里是**计算属性**而非 `@State` + `onChange`；没有行内错误文案，校验失败只表现为按钮灰色不可点

### `handleSubmit()`
- **签名**：`private func handleSubmit()`
- **触发**：「提交」按钮点击
- **步骤**：
  1. `isSending = true`
  2. `HTTPClient.shared.sendEmailVerificationCode(email: email)`
  3. 回调内 `DispatchQueue.main.async` → `self.isSending = false`
  4. `.success(let response)` 且 `response.isSuccess`：
     1. `alertMessage = "验证码已发送到您的邮箱"`（**写死文案，不用后端 `msg`**）
     2. `showAlert = true`
     3. `DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)` → `self.navigateToReset = true`（延迟 1.5s 推进重置页，注释写的是「让用户看到提示」）
  5. `.success` 但 `!response.isSuccess`：`alertMessage = response.msg ?? "发送验证码失败"` + `showAlert = true`，**不跳转**
  6. `.failure(let error)`：`alertMessage = error.localizedDescription` + `showAlert = true`，**不跳转**
- **失败处理**：弹 `alert`，停留本页，邮箱内容保留，用户可再次点击提交（无倒计时限制）

本页**没有其它 `private func`**。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `sendEmailVerificationCode` | POST | `/service/user/sendEmailVertifyCode` | 点「提交」 | `docs/api/user.md` §6 |

该接口在后端**鉴权白名单**内（无需 token）。

### 6.1 `sendEmailVerificationCode`

- **Swift 签名**：`func sendEmailVerificationCode(email: String, completion: @escaping (Result<BaseResponse<EmptyData>, NetworkError>) -> Void)`（`HTTPClient.swift` 第 274 行）
- **APIEndpoint**：`.sendEmailVertifyCode` → `Constants.API.sendEmailVertifyCode = "/service/user/sendEmailVertifyCode"`，method `"POST"`
  （**路径拼写是 `Vertify`，与后端一致；Swift 方法名却是 `Verification`**）
- **底层**：`request(endpoint: .sendEmailVertifyCode, parameters: parameters)`，POST 时 `parameters` 被 `JSONSerialization` 序列化成 JSON body
- **请求**：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `email` | Body | String | 是 | 收件邮箱（后端实体 `MailRequest`） |

- **响应**：`BaseResponse<EmptyData>`，后端文档 §6 出参示例中 `data` / `msg` / `total` / `token` 全为 `null`，只有 `status`。
  与其它业务方法不同，`sendEmailVerificationCode` **把整个 `BaseResponse` 原样交给页面**，
  不把 `status == "FAIL"` 转成 `.failure`，因此页面必须自己判 `response.isSuccess`（本页做了，[LoginPage](LoginPage.md) 没完全做）。
- **UI 处理**：
  - `isSuccess` → alert「验证码已发送到您的邮箱」+ 1.5 秒后 push `ResetPasswordPage(email: email)`
  - `!isSuccess` → alert（文案取后端 `msg`，兜底「发送验证码失败」），留在本页
  - `.failure` → alert（`error.localizedDescription`），留在本页
  - **不写任何缓存**，邮箱只通过 `ResetPasswordPage` 的构造参数传递

## 7. 数据模型

本页不涉及业务模型，只用到：

- `BaseResponse<T>`（`Models/BaseResponse.swift`）：`data: T?`、`token: String?`、`status: String`、`msg: String?`、`total: Int?`、`isSuccess: Bool { status == "SUCCESS" }`
- `EmptyData`（`Models/BaseResponse.swift` 第 46 行）：`struct EmptyData: Codable {}`，用于 `data` 为 null 的响应
- `NetworkError`（`HTTPClient.swift` 第 4 行）：`invalidURL` / `noData` / `decodingError` / `networkError` / `serverError(statusCode:)` / `unauthorized` / `custom(message:)`，`localizedDescription` 给出中文文案

唯一跨页数据是 `email: String`，通过 `ResetPasswordPage(email:)` 的 `let` 属性传入。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景（VStack + ScrollView 各设一次） | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor` |
| 导航栏内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 导航栏返回图标 | `chevron.left`，字号 `Dimens.middleIcon`(30)，色 `Colors.subColor` |
| 导航栏标题 | `Dimens.middleFont`(20)，`.black` |
| 导航栏底部分隔线 | `Rectangle` 高 1，`Colors.grayColor.opacity(0.3)` |
| 表单卡片 | 背景 `Colors.whiteColor`，圆角 `Dimens.borderRadius`(10) |
| 卡片外边距 | `.padding(.horizontal, Dimens.middleMargin)` + `.padding(.top, Dimens.middleMargin)` |
| 表单行内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 标签与内容间距 | `Dimens.middleMargin` |
| 必填星号 | `Text("*")`，`Colors.warnColor`，与标签间距 `2` |
| 输入文字 | `Dimens.normalFont`(17) |
| 提交按钮 | 高 `Dimens.btnHeight`(50)，圆角 `Dimens.btnHeight / 2`，可用 `Colors.primaryColor` / 禁用 `Colors.grayColor`，文字 `Colors.whiteColor` |
| 按钮内 loading | `ProgressView` tint `.white`（**未设 frame**） |
| 按钮内图标/文字间距 | `Dimens.smallIcon`(15)（用图标常量当间距，见 §10） |
| 卡片与按钮间距 | `Dimens.middleMargin`（外层 VStack spacing） |

## 9. 交互流程

```
1. LoginPage 点「忘记密码？」→ fullScreenCover 弹出 ForgetPasswordPage（自带 NavigationStack）
2. 输入邮箱
     每次输入 → body 重算 isEmailValid
       非法 → 提交按钮 grayColor + disabled
       合法 → 提交按钮 primaryColor 可点
3. 点「提交」
     ├─ isSending = true（按钮「发送中...」+ 转圈 + 禁用）
     └─ POST /service/user/sendEmailVertifyCode { email }
          ├─ status == SUCCESS
          │    → alert「验证码已发送到您的邮箱」
          │    → 1.5 秒后 navigateToReset = true
          │    → navigationDestination push ResetPasswordPage(email: email)
          ├─ status == FAIL
          │    → alert(msg ?? "发送验证码失败")，留在本页
          └─ 网络错误 / 401 / 解码失败
               → alert(error.localizedDescription)，留在本页
4. ResetPasswordPage 中输入验证码 + 新密码 → 重置成功后直接进 CompanyPage
5. 或点导航栏返回 → dismiss() → 回到 LoginPage
```

边界条件：

- **没有发送频率限制**：本页无倒计时（[LoginPage](LoginPage.md) 的邮箱登录 Tab 有 60s 倒计时），失败后可无限次点击提交。
- **邮箱是否已注册在本页无法判断**：接口只负责发送，未注册邮箱的处理取决于后端返回 `status`。
- **不校验登录态**：接口在白名单内，无 token 也能调用。
- **无缓存读写**。

## 10. 二次开发指引

- **改文案 / 样式**：标题在 `customNavigationBar`；标签「邮箱」与占位「请输入注册邮箱」在 `body` 的 `formRow(...)` 调用处；按钮文案在提交 `Button` 的 `Text(isSending ? ... : ...)`。
- **加字段**（例如同时支持手机号找回）：
  1. 加 `@State private var telephone`
  2. `body` 里追加 `formRow(...)`（需要分割线时得自己写，本页**没有** `DividerLine()`，可从 [RegisterPage](RegisterPage.md) 拷）
  3. 扩展 `isEmailValid` 的判定或改成组合校验
  4. `HTTPClient.sendEmailVerificationCode` 的 `parameters` 加键 + 改签名
  5. 后端 `MailRequest` 实体 + `docs/api/user.md`
- **加倒计时防重复发送**：参考 [LoginPage](LoginPage.md) 的 `startCountdown()` + `countdown` + `timer` 三件套（记得在 `onDisappear` 里 `invalidate`）。
- **加接口**：`Constants.API` → `APIEndpoints.swift` 的 `case` + `path` + `method`（三处）→ `HTTPClient` 方法 → 页面调用。

### 已知坑 / 注意事项

1. **alert 与自动跳转打架**：成功后先 `showAlert = true`，1.5 秒后又 `navigateToReset = true`。用户还没点掉「确定」，`ResetPasswordPage` 就被 push 上来了，alert 与新页面会叠在一起。要么改成 alert 的确定按钮里触发跳转，要么去掉 alert。
2. **成功文案硬编码，丢掉了后端 `msg`**：`alertMessage = "验证码已发送到您的邮箱"`，后端的成功提示被忽略（失败分支才用 `msg`）。
3. **`isEmailValid` 是计算属性，每帧重建 `NSPredicate`**：`body` 求值两次读它（按钮底色 + `disabled`），每次都新建正则谓词。字段多了会有可感知开销；[LoginPage](LoginPage.md) / [RegisterPage](RegisterPage.md) 用的是 `@State` + `onChange` 缓存结果，三处实现不统一。
4. **邮箱正则的第三份拷贝**：同一段正则字符串在 `LoginPage.validateEmail()`、`RegisterPage.validateEmail()`、本页 `isEmailValid` 各存了一份，改规则要改三处。建议抽到 `Utils`。
5. **没有行内错误提示**：邮箱格式不对时只有按钮变灰，不像 [RegisterPage](RegisterPage.md) 有红字「请输入正确的邮箱地址」，用户不知道为什么点不了。
6. **无发送频率限制**：见 §9。
7. **`formRow` 缺少固定标签列宽**：本页 `formRow` **没有** `.frame(width: 80, alignment: .leading)`，而 [RegisterPage](RegisterPage.md) / [ResetPasswordPage](ResetPasswordPage.md) 的同名方法有。三份实现独立拷贝，标签列宽不一致，多字段时对不齐。
8. **导航栏返回图标颜色与 RegisterPage 不一致**：本页与 [ResetPasswordPage](ResetPasswordPage.md) 用 `Colors.subColor`（中灰），[RegisterPage](RegisterPage.md) 用 `Colors.grayColor`（浅灰）。
9. **`Dimens.smallIcon` 被当作间距用**：按钮内 `HStack(spacing: Dimens.smallIcon)`，不符合「所有间距统一用 `Dimens.middleMargin`」的样式铁律（同样的问题在 [RegisterPage](RegisterPage.md) / [ResetPasswordPage](ResetPasswordPage.md) 也存在）。
10. **`NavigationStack` 嵌在 `fullScreenCover` 里**：本页是被 `LoginPage` 以 `fullScreenCover` 弹出的，自带 `NavigationStack`；而 `ResetPasswordPage` 成功后又用 `fullScreenCover` 弹 `CompanyPage`。这条「cover → push → cover」的混合链路会让导航栈里残留 `ForgetPasswordPage` + `ResetPasswordPage`，`CompanyPage` 关闭时的回退路径不直观。
11. **`ProgressView` 未限制尺寸**：按钮内的 `ProgressView` 没有 `.frame(...)`（[LoginPage](LoginPage.md) 设了 `Dimens.smallIcon`），依赖系统默认大小。
12. **共享文档中的底层签名与实现不符**：真实签名是 `request<T: Codable>(endpoint:method:parameters:customBody:customHeaders:completion:)`（`HTTPClient.swift` 第 57 行），不是共享文档写的 `request<T>(endpoint:body:queryItems:completion:)`。

## 相关文档

- [LoginPage](LoginPage.md) —— 本页的入口
- [ResetPasswordPage](ResetPasswordPage.md) —— 本页的下一步
- [RegisterPage](RegisterPage.md)、[WelcomePage](WelcomePage.md)
