---
name: welcome-page
description: App 启动页（token 自检 + 路由分发）。当你需要修改冷启动逻辑、登录态校验、启动动画/Logo，或排查「一进 App 就跳登录页」问题时读这份文档。
page: WelcomePage.swift
path: chat/chat/UI/Pages/WelcomePage.swift
apis:
  - GET /service/user/getUserData
---

# WelcomePage（启动页）

## 1. 页面职责

App 的唯一根视图（由 `ChatApp.swift` 的 `WindowGroup` 直接渲染），负责冷启动时的**登录态自检**与**首屏路由分发**。

它只做一件事：读取本地 token，若存在就用 `getUserData` 向服务端换取用户信息，成功则进入 `CompanyPage` 选公司，失败或无 token 则弹出 `LoginPage`。页面本身没有任何可交互控件，视觉上只有一个居中的品牌 Logo。

它是整条鉴权链路的入口，也是「token 过期 → 回到登录」的唯一兜底点。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/WelcomePage.swift`（约 76 行，含 `#Preview`）
- **入口**：`chat/chat/App/ChatApp.swift` 中 `WindowGroup { WelcomePage() }`，**无父页面**，是根视图
- **出口**：
  - `LoginPage`（`fullScreenCover`，`showLoginPage`）—— 无 token 或 `getUserData` 失败
  - `CompanyPage`（`fullScreenCover`，`navigateToCompanyPage`）—— token 有效
- **依赖组件**：`UI/Components/AIAvatar.swift`（`AIAvatar.large()`）
- **依赖模型**：`Models/User.swift`、`Models/BaseResponse.swift`、`Models/AppState.swift`
- **依赖服务**：
  - `HTTPClient.shared.getUserData(completion:)`
  - `AppState.shared.updateUserData(_:)` / `AppState.shared.isLoggedIn`
  - `TokenManager.shared.getToken()`
- **主题**：`Colors.pageBackgroundColor`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState`（`@ObservedObject private`） | `AppState` | `AppState.shared` | 全局状态单例引用；本页只写不读（读写都直接用 `AppState.shared`） |
| `isCheckingLogin`（`@State private`） | `Bool` | `true` | 「正在校验登录态」标记；`true` 时在 Logo 下方显示 `ProgressView` 加载指示（见 §4） |
| `showLoginPage`（`@State private`） | `Bool` | `false` | 控制 `LoginPage` 的 `fullScreenCover` |
| `navigateToCompanyPage`（`@State private`） | `Bool` | `false` | 控制 `CompanyPage` 的 `fullScreenCover` |

无 `@StateObject` / `@Binding` / `@Environment`。

## 4. 视图结构

```
body: ZStack
├─ Colors.pageBackgroundColor.ignoresSafeArea()      页面背景 RGB(239,239,239)
└─ VStack
   ├─ Spacer()
   ├─ AIAvatar.large()                               = AIAvatar.largeSquare()，80x80 方形
   ├─ if isCheckingLogin { ProgressView() }          校验中的加载指示（tint primaryColor）
   └─ Spacer()

修饰器（挂在 ZStack 上）
├─ .onAppear { checkLoginStatus() }
├─ .fullScreenCover(isPresented: $showLoginPage)        { LoginPage() }
└─ .fullScreenCover(isPresented: $navigateToCompanyPage){ CompanyPage() }
```

`AIAvatar.large()` 内部为 `largeSquare()`：`size = Dimens.bigAvater`(80)、`shape = .square`，
优先加载 Asset 里的 `logo` 图片；取不到时降级为 `Colors.primaryColor.opacity(0.7)` 底 + `cpu.fill` 白色图标。

> 上下两个 `Spacer()` 把 Logo 垂直居中；VStack 未指定 `spacing`，用系统默认值。

## 5. 核心方法

### `checkLoginStatus()`

- **签名**：`private func checkLoginStatus()`
- **触发**：`.onAppear`（App 冷启动首帧）
- **步骤**：
  1. `if TokenManager.shared.getToken() != nil` —— 从 `UserDefaults`（key `auth_token`）读 token 判断存在性，不取用其值。
  2. **有 token 分支**：调用 `HTTPClient.shared.getUserData { result in ... }`，回调内 `DispatchQueue.main.async` 切主线程：
     - `.success(let userData)`：
       1. `AppState.shared.updateUserData(userData)`
       2. `AppState.shared.isLoggedIn = true`
       3. `self.navigateToCompanyPage = true` → 弹出 `CompanyPage`
     - `.failure(let error)`：
       1. `print("获取用户信息失败: \(error.localizedDescription)")`
       2. `AppState.shared.isLoggedIn = false`
       3. `self.showLoginPage = true` → 弹出 `LoginPage`
     - 两个分支最后统一 `isCheckingLogin = false`
  3. **无 token 分支**：`DispatchQueue.main.asyncAfter(deadline: .now() + 1)`（**硬编码延迟 1 秒**）后依次
     `isCheckingLogin = false`、`AppState.shared.isLoggedIn = false`、`showLoginPage = true`。
- **失败处理**：不弹 `alert`，只 `print` 到控制台，然后静默降级到 `LoginPage`。用户看不到任何错误提示。

本页**没有其它 `private func`**，也没有 `private var xxxView` 拆分的子视图。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getUserData` | GET | `/service/user/getUserData` | `.onAppear` 且本地存在 token | `docs/api/user.md` §3 |

### 6.1 `getUserData`

- **Swift 签名**：`func getUserData(completion: @escaping (Result<User, NetworkError>) -> Void)`
  （`Network/HTTPClient.swift` 第 254 行，`extension HTTPClient`）
- **APIEndpoint**：`.getUserData` → `Constants.API.getUserData = "/service/user/getUserData"`，`method` 分支归为 `"GET"`
- **底层**：`request(endpoint: .getUserData) { (result: Result<BaseResponse<User>, NetworkError>) in ... }`
- **请求**：

| 名称 | 位置 | 类型 | 必填 | 说明 |
|---|---|---|---|---|
| （无业务参数） | — | — | — | 只带 `Authorization: Bearer <token>` 请求头，由 `TokenManager.shared.getAuthorizationHeader()` 注入 |
| `X-User-Id` | Header | String | 是（网关注入） | 网关解析 JWT 后透传给下游，**客户端不传** |

- **响应**：`BaseResponse<User>`，后端文档 §3 出参示例中 `data` 为用户对象、`token` 为**新签发**的凭证。

| data 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String? | 用户 ID |
| `userAccount` | String | 账号 |
| `username` | String | 昵称 |
| `telephone` | String | 电话 |
| `email` | String | 邮箱 |
| `avater` | String? | 头像地址（注意拼写是 `avater`） |
| `birthday` | String? | 出生年月日 |
| `sex` | String | `"0"` 男 / `"1"` 女 |
| `role` | String? | 角色 |
| `sign` | String | 个性签名 |
| `region` | String? | 地区 |
| `disabled` | Int? | 0 不禁用 / 1 禁用 |
| `permission` | Int? | 权限大小 |

- **UI 处理**：
  - `HTTPClient` 层：`BaseResponse.token` 非空时，**通用 `request` 方法**先 `TokenManager.shared.saveToken(token)`；
    `getUserData` 内部**再一次** `TokenManager.shared.saveToken(token)` + `AppState.shared.updateToken(token)`（token 会被续期两遍，无副作用但重复）。
  - 页面层成功：写 `AppState.userData`、`isLoggedIn = true`，置 `navigateToCompanyPage = true`。
  - 页面层失败：`isLoggedIn = false` + `showLoginPage = true`，无 UI 提示（**不再调用 `clearUserData()`**，本地 token 保留，供下次启动重新自检）。
  - HTTP 401 会在 `request` 中被转换为 `NetworkError.unauthorized`（文案「未授权，请重新登录」），走 `.failure` 分支。

## 7. 数据模型

本页只用到 `User`（`Models/User.swift`），字段见 §6.1 响应表。`User` 全部字段中 `userAccount` / `username` / `telephone` / `email` / `sex` / `sign` 为**非可选**，其余可选；`password` 仅注册时本地填充，服务端不回传。

`BaseResponse<T>`（`Models/BaseResponse.swift`）：`data: T?`、`token: String?`、`status: String`、`msg: String?`、`total: Int?`、`isSuccess: Bool { status == "SUCCESS" }`。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` + `.ignoresSafeArea()` |
| 中央 Logo | `AIAvatar.large()`，尺寸 `Dimens.bigAvater`(80)，方形 |
| Logo 降级底色 | `Colors.primaryColor.opacity(0.7)` |
| Logo 降级图标 | SF Symbol `cpu.fill`，占头像 50% |
| 垂直布局 | `VStack` + 上下 `Spacer()` |

本页没有卡片、按钮、输入框，因此不涉及 `Dimens.borderRadius` / `btnHeight` / `inputHeight`。

## 9. 交互流程

```
App 冷启动
  └─ ChatApp → WelcomePage.body 渲染（Logo 居中）
       └─ onAppear → checkLoginStatus()
            ├─ TokenManager.getToken() != nil
            │    └─ GET /service/user/getUserData
            │         ├─ SUCCESS + data != nil
            │         │    → 保存新 token（HTTPClient 内自动）
            │         │    → AppState.updateUserData / isLoggedIn = true
            │         │    → fullScreenCover: CompanyPage
            │         └─ FAIL / 401 / 网络错误 / data 为空
            │              → isLoggedIn = false
            │              → fullScreenCover: LoginPage
            └─ token == nil
                 └─ 延迟 1.0s（asyncAfter）
                      → isLoggedIn = false
                      → fullScreenCover: LoginPage
```

边界条件：

- **token 存在但已过期**：网关返回 401 → `NetworkError.unauthorized` → 走失败分支置 `isLoggedIn = false`，用户无感知地看到登录页。
- **`status == "FAIL"` 或 `data` 为空**：`getUserData` 内部转成 `NetworkError.custom(message: response.msg ?? "获取用户信息失败")`，同样走失败分支。
- **无网络**：`NetworkError.networkError`，同样降级到 `LoginPage`（本地 token 保留、不再 `clearUserData()`；下次启动会用该 token 重新自检，网络恢复即可进入）。
- **缓存命中**：本页不读任何业务缓存（租户/模型/公司 ID 由 `CompanyPage` / `HomePage` 自己处理）。

## 10. 二次开发指引

- **改启动 Logo / 启动布局**：直接改 `body` 里的 `VStack`，或改 `AIAvatar` 便捷方法（`UI/Components/AIAvatar.swift` 的 `largeSquare()`）。换图只需替换 Asset 中名为 `logo` 的图片。
- **加启动 Loading 指示**：`isCheckingLogin` 已存在但未被消费，可在 `ZStack` 里加
  `if isCheckingLogin { ProgressView() }`，无需新增 state。
- **改路由目标**（比如登录后先进 HomePage）：改 `checkLoginStatus()` 成功分支的 `navigateToCompanyPage`，并同步换掉对应 `fullScreenCover` 的目标视图。
- **加字段**：`Models/User.swift` 新增字段（注意 `CodingKeys` 同步）→ 后端 `user` 表 + `docs/api/user.md` → 页面无需改（本页不展示用户字段）。
- **加接口**：`Constants.API` 加路径常量 → `APIEndpoints.swift` 的 `case` + `path` + `method` 三处都要加（`method` 是 `switch` 穷举，漏了不会编译过）→ `HTTPClient` 加业务方法 → 页面调用。

### 已知坑 / 注意事项

1. **同一视图挂了两个 `fullScreenCover`**：`.fullScreenCover(isPresented: $showLoginPage)` 与
   `.fullScreenCover(isPresented: $navigateToCompanyPage)` 直接叠加在同一个 `ZStack` 上。SwiftUI 对同一视图的多个同类 presentation 修饰器支持并不可靠（历史上存在只有最后一个生效的问题）。由于两条分支互斥、且同一时刻只有一个为 `true`，目前表现正常，但**新增第三个 cover 或改成可能同时为 true 的逻辑时会踩坑**。稳妥做法是改用单个枚举驱动的 `fullScreenCover(item:)`。
2. **无 token 时硬编码 1 秒延迟**：`asyncAfter(deadline: .now() + 1)` 是为了让 Logo 露一下脸，属于写死的体验参数，改动前先确认没有别处依赖这个时序。
3. **失败静默**：网络异常与 token 失效的处理完全相同（都是降级跳登录页），且只 `print`，线上无法区分"服务挂了"和"登录过期"。
4. **本页混用 `appState` 与 `AppState.shared`**：`@ObservedObject private var appState` 声明了但 `checkLoginStatus()` 里全部写成 `AppState.shared.xxx`，`appState` 实际只起到"订阅刷新"的作用。

## 相关文档

- [LoginPage](LoginPage.md) —— 未登录时的落地页
- [RegisterPage](RegisterPage.md)
- [ForgetPasswordPage](ForgetPasswordPage.md) → [ResetPasswordPage](ResetPasswordPage.md)
