---
name: register-page
description: 注册页（10 字段表单 + 账号防抖查重）。当你需要增删注册字段、改表单校验规则、改账号查重防抖，或排查「注册按钮一直灰着点不动」问题时读这份文档。
page: RegisterPage.swift
path: chat/chat/UI/Pages/RegisterPage.swift
apis:
  - POST /service/user/vertifyUser
  - POST /service/user/register
---

# RegisterPage（注册页）

## 1. 页面职责

新用户自助注册页。收集 10 个字段（账号、密码、确认密码、昵称、电话、邮箱、性别、出生日期、地区、个性签名），其中 4 个必填（账号、密码、确认密码、昵称）+ 邮箱也参与必填判定。

页面内置**账号防抖查重**（输入停止 1 秒后调 `vertifyUser`，右侧实时显示 ✓/✗）、**密码一致性校验**、**手机号与邮箱正则校验**，全部通过后注册按钮才可点。

注册成功即视为登录成功：写入 `AppState` 的用户信息与 token，直接全屏推进 `CompanyPage` 选公司，**不需要再走一次登录**。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/RegisterPage.swift`（约 529 行，含 `#Preview`）
- **入口**：[LoginPage](LoginPage.md) 底部「注册」按钮 → `handleRegister()` → `showRegisterPage = true` → `fullScreenCover`
- **出口**：
  - `CompanyPage`（`fullScreenCover`，`navigateToCompanyPage`）—— 注册成功
  - 返回 `LoginPage`：导航栏左侧 `chevron.left` → `@Environment(\.dismiss)`
- **依赖组件**：**无外部组件**。导航栏、分割线、表单行都是页内私有实现
  （`customNavigationBar`、`DividerLine()`、`formRow(label:isRequired:content:)`）
- **依赖模型**：`Models/User.swift`（本页手工构造 `User` 实例）、`Models/BaseResponse.swift`、`Models/AppState.swift`、`LoginResponse`
- **依赖服务**：
  - `HTTPClient.shared.vertifyUser(userAccount:completion:)`
  - `HTTPClient.shared.register(userData:completion:)`
  - `AppState.shared.updateUserData(_:)` / `updateToken(_:)`

## 3. 状态定义

**环境与全局**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState`（`@ObservedObject private`） | `AppState` | `AppState.shared` | 注册成功后写用户信息与 token |
| `dismiss`（`@Environment(\.dismiss) private`） | `DismissAction` | — | 导航栏返回按钮关闭本页 |

**流程状态（`@State private`）**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `isRegistering` | `Bool` | `false` | 注册请求中；按钮显示 `ProgressView` + 文案「注册中...」并禁用 |
| `showAlert` | `Bool` | `false` | 通用提示弹窗开关 |
| `alertMessage` | `String` | `""` | 弹窗文案 |
| `navigateToCompanyPage` | `Bool` | `false` | 控制 `CompanyPage` 的 `fullScreenCover` |

**表单字段（`@State private`）**

| 属性 | 类型 | 初值 | 必填 | 作用 |
|---|---|---|---|---|
| `userAccount` | `String` | `""` | 是 | 帐号（页面标签写作「帐号」） |
| `password` | `String` | `""` | 是 | 密码（`SecureField`） |
| `confirmPassword` | `String` | `""` | 是 | 确认密码（`SecureField`） |
| `username` | `String` | `""` | 是 | 昵称 |
| `telephone` | `String` | `""` | 否（标签无 `*`） | 电话，`keyboardType(.phonePad)` |
| `email` | `String` | `""` | 是 | 邮箱 |
| `selectedGender` | `String` | `"0"` | 否 | `"0"` 男 / `"1"` 女 |
| `birthday` | `Date` | `Date()`（当天） | 否 | `DatePicker` 紧凑样式 |
| `region` | `String` | `""` | 否 | 地区 |
| `sign` | `String` | `""` | 否 | 个性签名 |

**账号查重（`@State private`）**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `isVerifyingAccount` | `Bool` | `false` | 查重请求中，账号框右侧显示 `ProgressView` |
| `accountVerified` | `Bool` | `false` | 是否已完成过一次查重（`isFormValid` 的硬前提） |
| `accountExists` | `Bool` | `false` | 账号是否已被占用 |
| `verifyWorkItem` | `DispatchWorkItem?` | `nil` | 防抖任务句柄，输入变化时 `cancel()` |

**校验状态（`@State private`）**

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `isPhoneValid` | `Bool` | `true` | 手机号正则结果（空号视为合法） |
| `isEmailValid` | `Bool` | `true` | 邮箱正则结果（**空邮箱被置为 false**） |
| `isPasswordMatch` | `Bool` | `true` | 两次密码是否一致 |

**常量与计算属性**

| 名称 | 类型 | 说明 |
|---|---|---|
| `genderOptions`（`private let`） | `[String]` | `["男", "女"]`，索引即 `selectedGender` 的值 |
| `isFormValid`（`private var`） | `Bool` | 见 §5 |

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar                              白底 + 底部 1px 分隔线
└─ ScrollView                                       背景 Colors.pageBackgroundColor
   └─ VStack(spacing: Dimens.middleMargin)
      │   .padding(.horizontal, Dimens.middleMargin) .padding(.top, Dimens.middleMargin)
      ├─ 表单卡片 VStack(spacing: 0)
      │  │   .background(Colors.whiteColor) .cornerRadius(Dimens.borderRadius)
      │  ├─ formRow「帐号」*   TextField「请输入帐号」
      │  │     .onChange → handleAccountChange(newValue)
      │  │     .overlay(HStack { Spacer(); 状态图标 })
      │  │        isVerifyingAccount        → ProgressView 15x15
      │  │        accountVerified && 非空   → xmark.circle.fill(warnColor) / checkmark.circle.fill(.green)
      │  ├─ DividerLine()
      │  ├─ formRow「密码」*   SecureField「请输入密码」 .onChange → validatePasswordMatch()
      │  ├─ DividerLine()
      │  ├─ formRow「确认密码」* VStack(alignment: .trailing, spacing: Dimens.smallIcon)
      │  │     SecureField「请再次输入密码」 .onChange → validatePasswordMatch()
      │  │     if !isPasswordMatch && !confirmPassword.isEmpty
      │  │        → Text「两次输入的密码不一致」 字号 normalFont-2，色 warnColor
      │  ├─ DividerLine()
      │  ├─ formRow「昵称」*   TextField「请输入昵称」
      │  ├─ DividerLine()
      │  ├─ formRow「电话」    VStack：TextField「请输入电话号码」(.phonePad) .onChange → validatePhone()
      │  │     错误文案「请输入正确的手机号码」（!isPhoneValid && 非空）
      │  ├─ DividerLine()
      │  ├─ formRow「邮箱」*   VStack：TextField「请输入邮箱」(.emailAddress, 不自动大写) .onChange → validateEmail()
      │  │     错误文案「请输入正确的邮箱地址」（!isEmailValid && 非空）
      │  ├─ DividerLine()
      │  ├─ formRow「性别」    HStack + ForEach(genderOptions.enumerated())
      │  │     单选圈：largecircle.fill.circle(primaryColor) / circle(grayColor)
      │  │     文字 normalFont 黑色，项间 Spacer()，PlainButtonStyle
      │  ├─ DividerLine()
      │  ├─ formRow「出生日期」 DatePicker(displayedComponents: .date) .labelsHidden() .datePickerStyle(.compact)
      │  ├─ DividerLine()
      │  ├─ formRow「地区」    TextField「请输入地区」
      │  ├─ DividerLine()
      │  └─ formRow「个性签名」 TextField「请输入个性签名」
      └─ Button(handleRegister) 注册
            HStack(spacing: Dimens.smallIcon)：isRegistering → ProgressView(tint: .white)
            文案 isRegistering ? "注册中..." : "注册"，色 Colors.whiteColor
            高 Dimens.btnHeight，底 isFormValid ? primaryColor : grayColor
            圆角 Dimens.btnHeight / 2
            .disabled(!isFormValid || isRegistering)
            .padding(.bottom, Dimens.middleMargin)

修饰器（挂在最外层 VStack 上）
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) } message: { Text(alertMessage) }
└─ .fullScreenCover(isPresented: $navigateToCompanyPage) { CompanyPage() }
```

**子视图 / 私有构建器**

```
customNavigationBar: HStack
├─ Button(dismiss) chevron.left  字号 Dimens.middleIcon(30)，色 Colors.grayColor
├─ Spacer()
├─ Text「注册」                  字号 Dimens.middleFont(20)，色 .black
├─ Spacer()
└─ Button 占位（chevron.left 透明色，disabled(true)）—— 保持标题居中
   .padding(.horizontal/.vertical, Dimens.middleMargin) .background(Colors.whiteColor)
   .overlay(Rectangle().fill(Colors.grayColor.opacity(0.3)).frame(height: 1), alignment: .bottom)

DividerLine(): Rectangle().fill(Colors.grayColor.opacity(0.3)).frame(height: 1)
               .padding(.leading, Dimens.middleMargin)

formRow(label:isRequired:content:): HStack(alignment: .center, spacing: Dimens.middleMargin)
├─ 标签 HStack(spacing: 2)：isRequired 时前置 Text("*") 色 Colors.warnColor
│     Text(label) 字号 normalFont 黑色
│     .frame(width: 80, alignment: .leading)      ← 固定 80pt 标签列
└─ content.frame(maxWidth: .infinity, alignment: .leading)
   .padding(.horizontal/.vertical, Dimens.middleMargin)
```

> 注意：`formRow` 里的输入框**没有边框和固定高度**，是「表格行」样式（靠 `DividerLine()` 分隔），
> 与 [LoginPage](LoginPage.md) 的胶囊描边输入框（`Dimens.inputHeight` / 圆角 `inputHeight/2`）是两套不同风格。

## 5. 核心方法

### `isFormValid`（计算属性）
- **签名**：`private var isFormValid: Bool`
- **规则**（10 个条件全部 `&&`）：
  1. `!userAccount.isEmpty`
  2. `!password.isEmpty`
  3. `!confirmPassword.isEmpty`
  4. `!username.isEmpty`
  5. `!email.isEmpty`
  6. `isPasswordMatch`
  7. `isPhoneValid`
  8. `isEmailValid`
  9. `accountVerified` —— **必须已经完成过一次账号查重**
  10. `!accountExists`
- **影响**：注册按钮底色与 `disabled`

### `handleAccountChange(_ newValue: String)`
- **触发**：账号 `TextField` 的 `.onChange(of: userAccount)`
- **步骤**：
  1. `verifyWorkItem?.cancel()` 取消上一次待执行的查重
  2. `guard !newValue.isEmpty else { accountVerified = false; accountExists = false; return }`
  3. 新建 `DispatchWorkItem { self.verifyAccount() }` 存入 `verifyWorkItem`
  4. `DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)` —— **1 秒防抖**
- **失败处理**：无

### `verifyAccount()`
- **触发**：防抖任务到期
- **步骤**：
  1. `guard !userAccount.isEmpty else { return }`
  2. `isVerifyingAccount = true`、`accountVerified = false`
  3. 调 `HTTPClient.shared.vertifyUser(userAccount: userAccount)`
  4. 回调切主线程：`isVerifyingAccount = false`、**`accountVerified = true`（成功失败都置真）**
  5. `.success(let data)`：`accountExists = (data == 1)`；若已存在则 `alertMessage = "该账号已被注册"` + `showAlert = true`
  6. `.failure(let error)`：只 `print("❌ 校验账号失败: ...")`，并把 `accountExists = false`
- **失败处理**：**静默放行**（见 §10 已知坑 1）

### `validatePasswordMatch()`
- **触发**：`password` / `confirmPassword` 的 `.onChange`
- **步骤**：`isPasswordMatch = password == confirmPassword`
- **注意**：两个都为空时也算「一致」（`true`），但 `isFormValid` 另有非空判断兜底

### `validatePhone()`
- **触发**：`telephone` 的 `.onChange`
- **步骤**：
  1. 空串直接 `isPhoneValid = true`（电话非必填）
  2. 正则 `^1[3-9]\d{9}$`（11 位中国大陆手机号）
- **失败处理**：行内红色文案「请输入正确的手机号码」

### `validateEmail()`
- **触发**：`email` 的 `.onChange`
- **步骤**：
  1. **空串置 `isEmailValid = false`**（邮箱必填）
  2. 正则 `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}`
- **失败处理**：行内红色文案「请输入正确的邮箱地址」（仅在非空时展示）

### `formatDate(_ date: Date) -> String`
- **触发**：`handleRegister()` 构造 `User` 时
- **步骤**：`DateFormatter`，`dateFormat = "yyyy-MM-dd"`

### `handleRegister()`
- **触发**：注册按钮点击
- **步骤**：
  1. **兜底校验（按顺序 early return）**：
     - `!isPasswordMatch` → alert「两次输入的密码不一致」
     - `!isPhoneValid && !telephone.isEmpty` → alert「请输入正确的手机号码」
     - `!isEmailValid` → alert「请输入正确的邮箱地址」
     - `accountExists` → alert「该账号已被注册」
  2. `isRegistering = true`
  3. 构造 `User`（**`var userData`，但之后从未修改**）：
     `id: nil, userAccount, createDate: nil, updateDate: nil, username, telephone, email,`
     `avater: nil, birthday: formatDate(birthday), sex: selectedGender, role: nil,`
     `password: password, sign: sign, region: region, disabled: nil, permission: nil`
  4. `HTTPClient.shared.register(userData: userData)`
  5. 回调切主线程 → `isRegistering = false`
  6. `.success(let loginResponse)`：
     `appState.updateUserData(loginResponse.userData)` → `appState.updateToken(loginResponse.token)`
     → `navigateToCompanyPage = true`
  7. `.failure(let error)`：`alertMessage = error.localizedDescription` + `showAlert = true`
- **失败处理**：弹 `alert`，表单内容全部保留

> 注册成功后**没有显式调用 `TokenManager.shared.saveToken`**，token 落地依赖两条隐式路径：
> ① `HTTPClient.request` 解码到 `response.token` 时会 `saveToken`；② `AppState.updateToken` 内部也会 `saveToken` 并置 `isLoggedIn = true`。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `vertifyUser` | POST | `/service/user/vertifyUser` | 账号输入停止 1 秒后（防抖） | `docs/api/user.md` §9 |
| 2 | `register` | POST | `/service/user/register` | 点「注册」且 `isFormValid` | `docs/api/user.md` §1 |

两个接口都在后端**鉴权白名单**内（无需 token）。

### 6.1 `vertifyUser`

- **Swift 签名**：`func vertifyUser(userAccount: String, completion: @escaping (Result<Int, NetworkError>) -> Void)`（`HTTPClient.swift` 第 825 行）
- **APIEndpoint**：`.vertifyUser` → `Constants.API.vertifyUser = "/service/user/vertifyUser"`，method `"POST"`
  （**`vertifyUser` 是客户端与后端一致的拼写错误，正确英文应为 `verifyUser`；改名必须两端同步**）
- **请求**（JSON Body）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `userAccount` | Body | String | 是 | 待查重的账号（后端实体 `UserCreate`，也支持 `username`，客户端只传 `userAccount`） |

- **响应**：`BaseResponse<Int>`。客户端要求 `isSuccess && data != nil`，把 `data`（`Int`）回传；
  否则转 `NetworkError.custom(message: response.msg ?? "校验账号失败")`。
  页面约定 **`data == 1` 表示账号已存在**，其它值表示可用。
  > 后端文档 §9 的出参示例中 `data` 为 `null`，**未说明 0/1 语义**。此处「1 = 已存在」是按客户端
  > `self.accountExists = (data == 1)` 的实现推断，后端文档未覆盖。
- **UI 处理**：
  - 请求中 → 账号框右侧 `ProgressView`
  - 已存在 → 红色 `xmark.circle.fill` + alert「该账号已被注册」，`isFormValid` 变 false
  - 可用 → 绿色 `checkmark.circle.fill`
  - 失败 → 只 `print`，`accountVerified` 仍置 true 且 `accountExists = false`

### 6.2 `register`

- **Swift 签名**：`func register(userData: User, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void)`（`HTTPClient.swift` 第 843 行）
- **APIEndpoint**：`.register` → `Constants.API.register = "/service/user/register"`，method `"POST"`
- **请求**（JSON Body，由 `HTTPClient` 从 `User` 展开成 **9 个字段**）：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| `userAccount` | Body | String | 是 | `userData.userAccount` |
| `password` | Body | String | 是 | `userData.password?.md5 ?? ""` —— **MD5 在 HTTPClient 内加密** |
| `username` | Body | String | 是 | 昵称 |
| `telephone` | Body | String | 是（可为空串） | 页面非必填，但 `User.telephone` 非可选，未填时传 `""` |
| `email` | Body | String | 是 | 邮箱 |
| `sex` | Body | String | 是 | `"0"` / `"1"` |
| `birthday` | Body | String | 是（可为空串） | `userData.birthday ?? ""`，页面总会传 `yyyy-MM-dd` |
| `region` | Body | String | 是（可为空串） | `userData.region ?? ""` |
| `sign` | Body | String | 是（可为空串） | 个性签名 |

  **未提交的字段**：`id` / `createDate` / `updateDate` / `avater` / `role` / `disabled` / `permission`
  （`User` 里有，但 `HTTPClient.register` 的 `parameters` 没带）。

- **响应**：`BaseResponse<User>`。客户端判定成功需
  `isSuccess && data != nil && token != nil`，组装 `LoginResponse`；
  否则 `NetworkError.custom(message: response.msg ?? "注册失败")`。
  > **与后端文档的差异**：`docs/api/user.md` §1 的注册出参示例中 `data` 和 `token` 都是 `null`。
  > 若后端真的不回 `data`/`token`，客户端会把成功注册误判为「注册失败」。以后端实际返回为准。
- **UI 处理**：成功 → 写 `AppState`（用户信息 + token）→ 弹 `CompanyPage`；失败 → alert。

## 7. 数据模型

`User`（`Models/User.swift`），本页会**手工构造完整实例**，因此所有字段都要关注：

| 字段 | 类型 | 本页取值 | 业务含义 |
|---|---|---|---|
| `id` | `String?` | `nil` | 服务端生成 |
| `userAccount` | `String` | 表单 | 账号（登录用），后端表 `user.user_account` varchar(32) |
| `createDate` | `String?` | `nil` | 服务端生成 |
| `updateDate` | `String?` | `nil` | 服务端生成 |
| `username` | `String` | 表单 | 昵称 |
| `telephone` | `String` | 表单（可空串） | 电话，后端 varchar(20) |
| `email` | `String` | 表单 | 邮箱 |
| `avater` | `String?` | `nil` | 头像地址（注意拼写 `avater`） |
| `birthday` | `String?` | `formatDate(birthday)` | `yyyy-MM-dd`，后端 varchar(16) |
| `sex` | `String` | `selectedGender` | `"0"` 男 / `"1"` 女 |
| `role` | `String?` | `nil` | 角色 |
| `password` | `String?` | 明文表单值（HTTPClient 内 MD5） | 仅注册/登录用，服务端不回传 |
| `sign` | `String` | 表单（可空串） | 个性签名 |
| `region` | `String?` | 表单（可空串） | 地区 |
| `disabled` | `Int?` | `nil` | 0 不禁用 / 1 禁用 |
| `permission` | `Int?` | `nil` | 权限大小 |

`LoginResponse`（`HTTPClient.swift` 第 1608 行）：`userData: User` + `token: String`，本地组装体、非 Codable。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景（含 ScrollView 背景） | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor` |
| 导航栏内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 导航栏返回图标 | `chevron.left`，字号 `Dimens.middleIcon`(30)，色 `Colors.grayColor` |
| 导航栏标题 | `Dimens.middleFont`(20)，`.black` |
| 导航栏底部分隔线 | `Rectangle` 高 1，`Colors.grayColor.opacity(0.3)` |
| 表单卡片 | 背景 `Colors.whiteColor`，圆角 `Dimens.borderRadius`(10) |
| 卡片外边距 | `.padding(.horizontal, Dimens.middleMargin)` + `.padding(.top, Dimens.middleMargin)` |
| 表单行内边距 | `Dimens.middleMargin`（水平 + 垂直） |
| 表单行内标签/内容间距 | `Dimens.middleMargin` |
| 标签列宽 | 固定 `80`（写死值，非 `Dimens` 常量） |
| 必填星号 | `Text("*")`，`Colors.warnColor`，与标签间距 `2` |
| 行分割线 | 高 1，`Colors.grayColor.opacity(0.3)`，左缩进 `Dimens.middleMargin` |
| 输入文字 | `Dimens.normalFont`(17) |
| 行内错误文案 | `Dimens.normalFont - 2`(15)，`Colors.warnColor` |
| 错误文案与输入框间距 | `Dimens.smallIcon`(15)（用图标常量当间距，见 §10） |
| 账号查重图标 | `checkmark.circle.fill` `.green` / `xmark.circle.fill` `Colors.warnColor`，字号 `Dimens.smallIcon` |
| 查重 loading | `ProgressView` `Dimens.smallIcon` × `Dimens.smallIcon` |
| 性别单选选中/未选 | `largecircle.fill.circle` + `Colors.primaryColor` / `circle` + `Colors.grayColor` |
| 注册按钮 | 高 `Dimens.btnHeight`(50)，圆角 `Dimens.btnHeight / 2`，可用 `Colors.primaryColor` / 禁用 `Colors.grayColor`，文字 `Colors.whiteColor` |
| 按钮内 loading | `ProgressView` tint `.white` |
| 卡片与按钮间距 | `Dimens.middleMargin`（外层 VStack spacing） |

## 9. 交互流程

**账号查重（防抖）**

```
用户每敲一个字符
  └─ onChange → handleAccountChange(newValue)
       ├─ 取消上一个 DispatchWorkItem
       ├─ 若清空 → accountVerified = false, accountExists = false（图标消失，按钮变灰）
       └─ 排一个 1 秒后的 WorkItem
            └─ 1 秒内无新输入 → verifyAccount()
                 ├─ isVerifyingAccount = true（右侧转圈）
                 └─ POST /service/user/vertifyUser { userAccount }
                      ├─ SUCCESS data == 1 → accountExists = true → 红叉 + alert「该账号已被注册」
                      ├─ SUCCESS data != 1 → accountExists = false → 绿勾
                      └─ 失败 → 仅 print；accountVerified = true / accountExists = false（按钮仍可点）
```

**完整注册链路**

```
1. LoginPage 点「注册」→ fullScreenCover 弹出 RegisterPage
2. 逐项填写；每个字段的 onChange 即时校验
     密码/确认密码 → validatePasswordMatch()
     电话         → validatePhone()（空号合法）
     邮箱         → validateEmail()（空号非法）
     账号         → 防抖查重
3. isFormValid 十条全真 → 注册按钮变主色可点
4. 点「注册」→ handleRegister()
     ├─ 四道兜底校验（不一致 / 手机号 / 邮箱 / 账号已存在）→ 命中即 alert 并 return
     ├─ isRegistering = true（按钮「注册中...」+ 转圈 + 禁用）
     └─ 构造 User → POST /service/user/register（password 走 MD5）
          ├─ SUCCESS 且 data + token 齐备
          │    → appState.updateUserData / updateToken（内部 saveToken + isLoggedIn = true）
          │    → navigateToCompanyPage = true → fullScreenCover: CompanyPage
          └─ 失败 → alert(error.localizedDescription)，表单保留
5. 或点导航栏返回 → dismiss() → 回到 LoginPage
```

边界条件与权限：

- 本页**不涉及任何角色/权限判断**，注册出的用户 `role` 为 `nil`（普通成员，见共享文档 §1.5）。
- 本页**不读写任何 `UserDefaults` 业务缓存**，token 由 `AppState.updateToken` / `HTTPClient` 落地。
- 注册成功后进入 `CompanyPage`，此时 `appState.currentCompany` 为 `nil`，`CompanyPage` 据此判定「非从 UserPage 进入」，会走首次选公司流程。

## 10. 二次开发指引

- **改文案 / 样式**：字段标签与占位在 `body` 内各个 `formRow(...)` 调用处；行样式改 `formRow`；分割线改 `DividerLine()`；导航栏改 `customNavigationBar`。
- **加一个注册字段**（例如「公司邮箱」），需要同时改 **5 处**：
  1. `Models/User.swift` 加属性 + `CodingKeys`
  2. `HTTPClient.register` 的 `parameters` 字典加键（**漏了这步字段不会上传，且不会报错**）
  3. `RegisterPage` 加 `@State` 字段
  4. `body` 里加 `formRow(...)` + `DividerLine()`
  5. 需要必填时同步 `isFormValid` 与 `handleRegister()` 的兜底校验
  6. 后端：`user` 表字段 + `UserCreate` 实体 + `docs/api/user.md`
- **改校验规则**：手机号正则在 `validatePhone()`，邮箱正则在 `validateEmail()`（注意 `LoginPage` / `ForgetPasswordPage` 各有一份拷贝）。
- **改防抖时长**：`handleAccountChange` 里的 `.now() + 1`。
- **加接口**：`Constants.API` → `APIEndpoints.swift` 的 `case` + `path` + `method`（三处）→ `HTTPClient` 方法 → 页面调用。

### 已知坑 / 注意事项

1. **查重接口失败会被当成「账号可用」**：`verifyAccount()` 的 `.failure` 分支把 `accountVerified = true` 且 `accountExists = false`，只 `print` 不提示。断网或后端异常时用户能直接提交，冲突要等 `register` 才暴露。
2. **`accountVerified` 是提交硬前提，且只由输入变化触发**：`isFormValid` 要求 `accountVerified == true`，而它只在 `handleAccountChange` → 1 秒防抖 → `verifyAccount()` 完成后才为真。若用户从剪贴板一次性粘贴或走了某些不触发 `onChange` 的路径，按钮会**永远灰着**。排查「按钮点不动」优先看这个状态。
3. **`var userData = User(...)` 应为 `let`**：`handleRegister()` 里构造后从未修改，Swift 会给出 "never mutated" 警告。
4. **`sign` / `region` / `telephone` 空值语义**：页面标注非必填，但 `User.sign`、`User.telephone` 是**非可选 String**，未填时提交空串 `""` 而不是 `null`。后端 `user` 表 `telephone` 为 `NOT NULL`，空串可入库，但业务上无法区分「没填」与「填了空」。
5. **出生日期默认当天且无范围限制**：`birthday = Date()`，`DatePicker` 未设 `in:` 范围，可以选到未来日期；用户不动这项就会提交注册当天的日期。
6. **`Dimens.smallIcon` 被当作间距使用**：确认密码/电话/邮箱行的 `VStack(spacing: Dimens.smallIcon)` 与按钮 `HStack(spacing: Dimens.smallIcon)` 用的是**图标常量**当间距，不符合「所有间距统一用 `Dimens.middleMargin`」的样式铁律。
7. **标签列宽写死 `80`**：`formRow` 的 `.frame(width: 80, alignment: .leading)` 是魔法数字，不是 `Dimens` 常量；且 [ForgetPasswordPage](ForgetPasswordPage.md) 的同名 `formRow` **没有**这个 `frame`，三份 `formRow` 实现并不一致。
8. **`DividerLine()` 命名不符 Swift 规范**：这是一个 `private func`，却用了大驼峰（像类型名）。同样的写法也出现在 [ResetPasswordPage](ResetPasswordPage.md)。
9. **「帐号」与「账号」用字不统一**：本页标签与占位是「帐号」，[LoginPage](LoginPage.md) 是「账号」，`vertifyUser` 的 alert 文案又是「该账号已被注册」。
10. **密码没有强度/长度校验**：只校验两次一致 + 非空。[ResetPasswordPage](ResetPasswordPage.md) 有 6 位下限校验，注册页没有，会出现「注册时能设 1 位密码，重置时却不允许」的不一致。
11. **`isEmailValid` / `isPhoneValid` 初值都是 `true`**：进入页面尚未输入时它们为真，`isFormValid` 靠 `!email.isEmpty` 兜住邮箱；电话是非必填所以无影响。但 `validateEmail()` 会在空串时把 `isEmailValid` 置 `false`，导致「输入后再清空邮箱」和「从未输入邮箱」两种状态下 `isEmailValid` 值不同（`false` vs `true`），属隐式不一致。
12. **注册成功不显式 `saveToken`**：依赖 `HTTPClient.request` 与 `AppState.updateToken` 的隐式保存（与 [LoginPage](LoginPage.md) 显式三连写法不一致）。改动 `AppState.updateToken` 时要注意本页会静默失去 token。
13. **无 `onDisappear` 清理**：`verifyWorkItem` 在页面关闭时不会被 cancel，1 秒内关页会执行一次无意义的查重请求。
14. **后端文档 `register` 出参示例与客户端解码要求冲突**：见 §6.2 末尾提示。

## 相关文档

- [LoginPage](LoginPage.md) —— 本页的入口
- [WelcomePage](WelcomePage.md)
- [ForgetPasswordPage](ForgetPasswordPage.md) → [ResetPasswordPage](ResetPasswordPage.md)
