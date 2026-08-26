# AGENTS.md

本文件是给 AI 智能体（Claude Code、Cursor、Copilot、Hermes 等）的项目接入说明。

## 项目概述

- 项目类型：iOS App（SwiftUI）
- 名称：chat —— 多公司 / 多租户下的 AI 对话客户端
- 能力：AI 流式对话（WebSocket）、大模型切换、提示词管理、知识库文档问答、会话记录、公司与租户成员权限管理
- 后端：FastAPI 微服务集群，统一走网关（客户端配置 `http://127.0.0.1:4000`）
- 后端项目路径：`/Users/wuwenqiang/Documents/code/python/fast-api-app-service`
- 后端接口文档：`/Users/wuwenqiang/Documents/code/python/fast-api-app-service/docs/api/`

## 必读文档（改代码前按顺序读）

1. **[提示词.md](提示词.md)** —— 项目开发规范（目录结构、UI 主题铁律、接口规范、代码输出要求）。**这是最高优先级约束。**
2. **[docs/README.md](docs/README.md)** —— 项目总览：架构、目录、导航全景图、主题常量表、接口全表、AppState 与缓存 key、角色权限口径、数据模型清单。
3. **[docs/pages/<页面名>.md](docs/pages/)** —— 要改哪个页面就读哪份。每份含：页面职责、位置与依赖、状态定义、视图结构树、核心方法、接口调用（含后端出入参）、数据模型、样式落地清单、交互流程、二次开发指引与**已知坑**。
4. 涉及后端字段时再读 `docs/api/<模块>.md`。

## 源码结构

```
chat/                            Xcode 工程根（本目录）
├── 提示词.md                     开发规范
├── docs/                        项目文档 / AI skill 文档
│   ├── README.md                总览 + 页面文档索引
│   ├── _共享上下文与文档模板.md    文档编写规范（新增/维护文档时读）
│   └── pages/*.md               每个页面一份
└── chat/                        源码根
    ├── App/ChatApp.swift        @main，根视图 = WelcomePage
    ├── UI/Pages/                完整页面（20 个）
    ├── UI/Components/           组件与弹窗（22 个）
    ├── Models/                  数据模型 + AppState + BaseResponse
    ├── Network/HTTPClient.swift 单例，统一 request<T> + 全部业务接口方法
    ├── Network/WebSocketManager.swift  AI 流式对话
    ├── Api/APIEndpoints.swift   APIEndpoint 枚举：path + method
    ├── Config/Constants.swift   baseURL / webSocketURL / Constants.API 路径表
    ├── Theme/Colors.swift       全部颜色
    ├── Theme/Dimens.swift       全部尺寸、字号、间距
    └── Utils/TokenManager.swift token 读写
```

## 硬性规范速查

- **UI 文件位置**：完整页面 → `UI/Pages/`；组件 → `UI/Components/`；模型 → `Models/`；接口路径与常量 → `Config/Constants.swift`；主题 → `Theme/Colors.swift` + `Theme/Dimens.swift`。
- **间距**：一律 `Dimens.middleMargin`（15）。
- **卡片式**：除 `HomePage`（聊天页）外所有页面模块都用卡片 —— 圆角 `Dimens.borderRadius`、背景 `Colors.whiteColor`、内边距 `Dimens.middleMargin`。
- **按钮**：高 `Dimens.btnHeight`，圆角 `Dimens.btnHeight / 2`；确定=`primaryColor` 底 + `whiteColor` 字；取消=透明底 + `grayColor` 边框与文字；禁用=`grayColor` 底；删除=`warnColor` 底。
- **输入框**：高 `Dimens.inputHeight`，圆角 `Dimens.inputHeight / 2`。
- **图标透明度**：统一 `0.5`。
- **字体**：正文 `Dimens.normalFont`(17)、主标题 `Dimens.middleFont`(20)、大标题 `Dimens.bigFont`(30)。
- **颜色**：页面背景 `Colors.pageBackgroundColor`、主色 `Colors.primaryColor`、警告/删除 `Colors.warnColor`、灰 `Colors.grayColor`、次要文字 `Colors.subColor`。

## 网络层规范

```
页面 → HTTPClient.shared.<业务方法>(...) { result in DispatchQueue.main.async { ... } }
          └→ HTTPClient.request<T>(endpoint: APIEndpoint, ...)
                 ├─ URL  = Constants.baseURL + endpoint.path
                 ├─ 方法 = endpoint.method
                 ├─ 头部 = Authorization: Bearer <TokenManager.shared token>
                 └─ 解码 = BaseResponse<T>（status == "SUCCESS" 才算成功，用 isSuccess 判断）
```

**新增一个接口必须改四处**（顺序固定）：

1. `Config/Constants.swift` → `Constants.API` 加路径常量
2. `Api/APIEndpoints.swift` → `APIEndpoint` 加 case，并在 `path`（含占位符替换）与 `method` 两个 switch 中补齐
3. `Network/HTTPClient.swift` → 加业务方法，回调 `(Result<T, NetworkError>) -> Void`
4. 页面中调用，回调里 `DispatchQueue.main.async` 后再改 `@State`

**注意**：后端返回的 snake_case 字段由后端 `ResultUtil` 自动转驼峰，客户端模型直接用驼峰，无需 `CodingKeys` 映射下划线。

## 全局状态与缓存

`AppState.shared`（ObservableObject 单例）：`userData` / `token` / `isLoggedIn` / `currentCompany` / `currentTenant` / `currentModel` / `currentPrompt` / `tenantList` / `modelList`。

UserDefaults key：

| key | 含义 |
|---|---|
| `auth_token` | 登录 token（`TokenManager` 读写） |
| `companyId_<userId>` | 按用户记住上次选的公司 |
| `current_tenant_id` | 当前租户 ID |
| `current_model_id` | 当前模型 ID |
| `current_prompt_id_<tenantId>` | 按租户记住选用的提示词 |

`clearUserData()` 清 token / 租户 / 模型缓存，**故意不清** `companyId_<userId>`。

## 角色权限

`role`：`2` 超级管理员 / `1` 管理员 / `0` 或 `nil` 普通成员。
`status`：`0` 禁用 / `1` 启用 / `2` 停用（`TenantStatus` 枚举）。

典型门禁：`HomePage` 菜单里的「模型管理」仅当 `appState.currentCompany?.role ?? 0 > 0` 才出现。

## 主流程

```
WelcomePage（校验 token）
  ├─ 无效 → LoginPage ─┬→ RegisterPage
  │                    └→ ForgetPasswordPage → ResetPasswordPage
  └─ 有效 → CompanyPage（选公司）→ HomePage（聊天主页）
                                    ├─ 头像 → UserPage → UserInfoPage / ChangePasswordPage /
                                    │                    TenantManagePage / UserManagePage / CompanyPage
                                    ├─ 菜单 → PromptManagePage → AddPromptPage
                                    └─ 菜单 → ModelManagePage → AddModelPage / UpdateModelPage
```

完整图见 [docs/README.md](docs/README.md) 第四节。

## 代码输出约定（来自 提示词.md）

- 修改后文件 **< 500 行** → 输出完整文件代码；**≥ 500 行** → 只输出完整的修改方法体或新增代码块。
- 输出代码后必须说明改了哪个文件、哪个方法或类。
- 公开方法与核心业务逻辑必须写注释。
