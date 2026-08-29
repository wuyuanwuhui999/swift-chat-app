# chat（SwiftUI AI 对话 App）项目文档 / AI Skill 索引

> 本目录是本项目的 **AI 可读技能文档（skill docs）**，同时也是项目描述文档。
> 每个页面一份 md，位于 [`pages/`](pages/)。让大模型改某个页面前，先让它读对应的页面文档 + 本 README。

---

## 一、项目概览

| 项 | 值 |
|---|---|
| 项目名 | chat |
| 平台 | iOS（SwiftUI） |
| 语言 | Swift |
| 架构 | 单向数据流：View ←→ `AppState`（ObservableObject 单例） + `HTTPClient` / `WebSocketManager` |
| 后端 | FastAPI 微服务集群，统一走网关 `http://127.0.0.1:4000` |
| 业务定位 | 多公司（Company）/ 多租户（Tenant）下的 AI 对话工具：可切换大模型、绑定提示词、上传文档做知识库问答，并带一套公司/租户成员与权限管理后台 |

核心业务对象层级：

```
Company（公司/企业）
  └─ Tenant（租户 / 空间）
       ├─ Prompt（提示词，按租户维度）
       ├─ Directory → Document（知识库目录与文档）
       └─ ChatHistory（会话记录，按 chatId 分组）
ChatModel（大模型配置，按 Company 维度）
User → CompanyUser / TenantUser（成员与角色）
```

---

## 二、目录结构

```
chat/                          Xcode 工程根
├── docs/                      ← 本文档目录
│   ├── README.md              本文件：总览 + 索引
│   ├── _共享上下文与文档模板.md   文档编写规范（改/加文档时先读）
│   └── pages/                 每个页面一份 skill 文档
├── 提示词.md                   项目开发规范（UI/接口/代码输出铁律）
└── chat/                      源码根
    ├── App/ChatApp.swift          @main 入口，根视图 = WelcomePage
    ├── ContentView.swift          Xcode 模板残留，未使用
    ├── UI/
    │   ├── Pages/                 完整页面（20 个）
    │   └── Components/            可复用组件与弹窗（22 个）
    ├── Models/                    数据模型 + AppState + BaseResponse
    ├── Network/
    │   ├── HTTPClient.swift       单例，统一 request<T> + 全部业务接口方法
    │   └── WebSocketManager.swift 单例，AI 流式对话
    ├── Api/APIEndpoints.swift     APIEndpoint 枚举：path + method
    ├── Config/Constants.swift     baseURL / webSocketURL / Constants.API 路径表
    ├── Theme/
    │   ├── Colors.swift           全部颜色
    │   └── Dimens.swift           全部尺寸、字号、间距
    ├── Utils/TokenManager.swift   token 读写（UserDefaults）
    ├── Utils/Validators.swift     表单校验工具（模型地址、邮箱格式，各页共用）
    └── Resources/ Assets.xcassets
```

---

## 三、页面文档索引

### 3.1 认证与启动

| 页面 | 说明 | 文档 |
|---|---|---|
| `WelcomePage` | 启动页，校验 token 决定去登录还是去选公司 | [WelcomePage.md](pages/WelcomePage.md) |
| `LoginPage` | 账号密码 / 邮箱验证码登录 | [LoginPage.md](pages/LoginPage.md) |
| `RegisterPage` | 注册 | [RegisterPage.md](pages/RegisterPage.md) |
| `ForgetPasswordPage` | 忘记密码，校验账号存在 | [ForgetPasswordPage.md](pages/ForgetPasswordPage.md) |
| `ResetPasswordPage` | 邮箱验证码重置密码 | [ResetPasswordPage.md](pages/ResetPasswordPage.md) |

### 3.2 主流程

| 页面 | 说明 | 文档 |
|---|---|---|
| `CompanyPage` | 选择公司（登录后必经；也用于后续切换公司） | [CompanyPage.md](pages/CompanyPage.md) |
| `HomePage` | **聊天主页**：AI 流式对话、租户/模型切换、文档问答、会话记录 | [HomePage.md](pages/HomePage.md) |

### 3.3 用户中心

| 页面 | 说明 | 文档 |
|---|---|---|
| `UserPage` | 我的页：个人资料编辑（头像 + 弹窗改昵称/电话/邮箱/性别/生日/地区/签名）、退出登录、二级页枢纽 | [UserPage.md](pages/UserPage.md) |
| `ChangePasswordPage` | 登录态下修改密码 | [ChangePasswordPage.md](pages/ChangePasswordPage.md) |
| `UserInfoPage` | **公司成员详情（只读）**，入参 `companyUser: CompanyUser`，由 `UserManagePage` 点列表项进入 | [UserInfoPage.md](pages/UserInfoPage.md) |

### 3.4 租户与成员管理

| 页面 | 说明 | 文档 |
|---|---|---|
| `TenantManagePage` | 租户列表与管理，可进入「添加租户成员」 | [TenantManagePage.md](pages/TenantManagePage.md) |
| `AddTenantUserPage` | 搜索用户并加入租户 | [AddTenantUserPage.md](pages/AddTenantUserPage.md) |
| `UserManagePage` | 公司成员管理，可进入「添加公司成员」与「成员详情」 | [UserManagePage.md](pages/UserManagePage.md) |
| `AddCompanyUserPage` | 搜索用户并加入公司（含部门/职位） | [AddCompanyUserPage.md](pages/AddCompanyUserPage.md) |

### 3.5 模型管理

| 页面 | 说明 | 文档 |
|---|---|---|
| `ModelManagePage` | 模型列表、删除（仅管理员可见入口） | [ModelManagePage.md](pages/ModelManagePage.md) |
| `AddModelPage` | 新增模型（ollama / online） | [AddModelPage.md](pages/AddModelPage.md) |
| `UpdateModelPage` | 编辑模型 | [UpdateModelPage.md](pages/UpdateModelPage.md) |

### 3.6 提示词管理

| 页面 | 说明 | 文档 |
|---|---|---|
| `PromptManagePage` | 提示词列表、选用、删除 | [PromptManagePage.md](pages/PromptManagePage.md) |
| `AddPromptPage` | 新增提示词 | [AddPromptPage.md](pages/AddPromptPage.md) |

### 3.7 未接入主链路

| 页面 | 说明 | 文档 |
|---|---|---|
| `MainView` | Xcode 模板占位页，未被引用 | [MainView.md](pages/MainView.md) |

---

## 四、导航全景图

跳转方式已逐一核对源码（`fSC` = `fullScreenCover`，`navDest` = `navigationDestination`）。

```
ChatApp(@main)
└─ WelcomePage ─────────────── 启动校验 token（GET /service/user/getUserData）
   ├─（无 token / 校验失败）fSC → LoginPage
   │                              ├─ fSC → RegisterPage ───────── fSC → CompanyPage
   │                              ├─ fSC → ForgetPasswordPage
   │                              │         └─ navDest → ResetPasswordPage ── fSC → CompanyPage
   │                              └─ fSC → CompanyPage
   └─（token 有效）fSC → CompanyPage
                         └─ navDest → HomePage（首次选公司后进入）
                              ├─ ChatHeader 头像 → fSC → UserPage
                              │                      ├─ fSC → ChangePasswordPage
                              │                      ├─ fSC → CompanyPage（切换公司，isFromUserPage=true → dismiss 返回）
                              │                      ├─ fSC → TenantManagePage
                              │                      │          └─ navDest → AddTenantUserPage
                              │                      └─ fSC → UserManagePage
                              │                                 ├─ navDest → AddCompanyUserPage
                              │                                 └─ navDest → UserInfoPage(companyUser:)
                              ├─ 菜单「提示词管理」→ fSC → PromptManagePage
                              │                              └─ navDest → AddPromptPage
                              ├─ 菜单「模型管理」（需 currentCompany.role > 0）→ fSC → ModelManagePage
                              │                                                    ├─ navDest → AddModelPage(onModelAdded:)
                              │                                                    └─ navDest → UpdateModelPage(model:)
                              └─ 弹窗层（UI/Components，overlay / actionSheet）
                                 TenantListPopup / ModelListPopup
                                 ChatHistoryDialog / PromptDialog
                                 DocumentPickerDialog
                                 UploadDocumentDialog / MyDocumentsDialog
```

要点：

- `CompanyPage` 是**双入口**页面：首次登录进入 → 选完公司 `navDest` 到 `HomePage`；从 `UserPage` 进入（此时 `appState.currentCompany != nil`，页面把 `isFromUserPage` 置 true）→ 选完只 `dismiss()` 返回。
- `UserManagePage` 管的是**公司成员**（`CompanyUser`），`TenantManagePage` 走的是**租户成员**（`AddTenantUserPage`）。两条线不要混。
- `MainView` / `ContentView` 未被任何页面引用，是 Xcode 模板残留。

---

## 五、全局约定（改任何页面都必须遵守）

### 5.1 主题常量

**颜色** `Theme/Colors.swift`

| 常量 | 值 | 用途 |
|---|---|---|
| `Colors.primaryColor` | RGB(255,174,0) | 主色调、确定按钮、选中态 |
| `Colors.warnColor` | RGB(255,59,48) | 删除、警告 |
| `Colors.grayColor` | RGB(221,221,221) | 边框、禁用态、占位 |
| `Colors.subColor` | RGB(128,128,128) | 副标题、次要文字 |
| `Colors.whiteColor` | 白 | 卡片背景、主色按钮文字 |
| `Colors.blackColor` | 黑 | 主要文字 |
| `Colors.pageBackgroundColor` | RGB(239,239,239) | 页面背景 |

**尺寸** `Theme/Dimens.swift`

| 常量 | 值 |
|---|---|
| `smallAvater` / `middleAvater` / `bigAvater` | 30 / 50 / 80 |
| `smallIcon` / `middleIcon` / `bigIcon` | 15 / 30 / 50 |
| `normalFont` / `middleFont` / `bigFont` | 17 / 20 / 30 |
| `smallMargin` / `middleMargin` / `largeMargin` | 10 / 15 / 20 |
| `btnHeight` / `smallBtnHeight` | 50 / 40 |
| `inputHeight` | 50 |
| `borderRadius` | 10 |

`Colors` 与 `Dimens` 都提供了 `Color` / `CGFloat` 扩展（如 `.themePrimary`、`.middleMargin`），两种写法等价。

### 5.2 样式铁律（源自 `提示词.md`）

1. **所有**间距统一 `Dimens.middleMargin`（图标间距、图文间距、布局边距、列表间隔）。
2. 除 `HomePage`（聊天页）外，所有页面模块用**卡片式**：圆角 `Dimens.borderRadius`、背景 `Colors.whiteColor`、内边距 `Dimens.middleMargin`。
3. 按钮高度 `Dimens.btnHeight`，圆角 `Dimens.btnHeight / 2`；确定=主色底白字，取消=透明底灰边灰字，禁用=灰底，删除=`Colors.warnColor` 底。
4. 输入框高度 `Dimens.inputHeight`，圆角 `Dimens.inputHeight / 2`。
5. 图标透明度统一 `0.5`。
6. 字体：正文 `normalFont`、主标题 `middleFont`、大标题 `bigFont`。

### 5.3 网络层

```
页面 → HTTPClient.shared.<业务方法>(...) { result in ... }
            └→ HTTPClient.request<T>(endpoint: APIEndpoint, ...)
                    ├─ URL   = Constants.baseURL + endpoint.path
                    ├─ 方法  = endpoint.method
                    ├─ 头部  = Authorization: Bearer <TokenManager token>
                    └─ 解码  = BaseResponse<T>
```

- 新增接口的**四步**：`Constants.API` 加路径 → `APIEndpoint` 加 case（`path` + `method`）→ `HTTPClient` 加业务方法 → 页面调用。
- 统一响应 `BaseResponse<T>`：`data` / `status`（`"SUCCESS"` 才算成功，用 `isSuccess` 判断）/ `msg` / `total`（仅分页）/ `token`（仅登录注册）。
- 后端返回的下划线字段由后端 `ResultUtil` 自动转驼峰，客户端模型直接用驼峰。
- 所有回调都要 `DispatchQueue.main.async` 后再改 `@State`。

### 5.4 接口路径 → 后端文档映射

后端文档根目录：`/Users/wuwenqiang/Documents/code/python/fast-api-app-service/docs/api/`

| 客户端调用前缀 | 后端模块 | 端口 | 文档 |
|---|---|---|---|
| `/service/user/...` | user-service | 4005 | `user.md` |
| `/service/chat/...` | chat-service | 4006 | `chat.md` |
| `/service/tenant/...` | tenant-service | 4007 | `tenant.md` |
| `/service/prompt/...` | prompt-service | 4008 | `prompt.md` |
| `/service/company/...` | company-service | 4011 | `company.md` |
| `/service/agent/...` | agent-service | 4010 | `agent.md` |

> 注：客户端 `Constants.baseURL` 指向 `127.0.0.1:4000`，后端文档写的网关端口是 `4009`；本地联调时以实际网关端口为准，**不一致是已知差异**。

### 5.5 客户端已用接口全表（`Constants.API`）

| 常量 | 方法 | 路径 |
|---|---|---|
| `login` | POST | `/service/user/login` |
| `register` | POST | `/service/user/register` |
| `logout` | POST | `/service/user/logout` |
| `getUserData` | GET | `/service/user/getUserData` |
| `sendEmailVertifyCode` | POST | `/service/user/sendEmailVertifyCode` |
| `loginByEmail` | POST | `/service/user/loginByEmail` |
| `vertifyUser` | POST | `/service/user/vertifyUser` |
| `resetPassword` | POST | `/service/user/resetPassword` |
| `updatePassword` | PUT | `/service/user/updatePassword` |
| `updateUser` | PUT | `/service/user/updateUser` |
| `updateAvater` | POST | `/service/user/updateAvater` |
| `getTenantList` | GET | `/service/tenant/getTenantList` |
| `getTenantUserList` | GET | `/service/tenant/getTenantUserList` |
| `searchTenantUsers` | GET | `/service/tenant/searchTenantUsers` |
| `addTenantUser` | POST | `/service/tenant/addTenantUser/{tenantId}/{userId}` |
| `addAdmin` | PUT | `/service/tenant/addAdmin/{tenantId}/{userId}` |
| `cancelAdmin` | PUT | `/service/tenant/cancelAdmin/{tenantId}/{userId}` |
| `getCompanyList` | GET | `/service/company/getCompanyList` |
| `getCompanyUsers` | GET | `/service/company/getCompanyUsers` |
| `searchCompanyUsers` | GET | `/service/company/searchUsers` |
| `addCompanyUser` | POST | `/service/company/addUser` |
| `getDepartments` | GET | `/service/company/getDepartments` |
| `getPositions` | GET | `/service/company/getPositions` |
| `getModelList` | GET | `/service/chat/getModelList` |
| `addModel` | POST | `/service/chat/addModel` |
| `updateModel` | PUT | `/service/chat/updateModel` |
| `deleteModel` | DELETE | `/service/chat/deleteModel/{modelId}` |
| `getDirectoryList` | GET | `/service/chat/getDirectoryList` |
| `createDir` | POST | `/service/chat/createDir` |
| `getDocListByDirId` | GET | `/service/chat/getDocListByDirId` |
| `uploadDoc` | POST | `/service/chat/uploadDoc/{tenantId}/{directoryId}` |
| `deleteDoc` | DELETE | `/service/chat/deleteDoc/{docId}` |
| `getChatHistory` | GET | `/service/chat/getChatHistory` |
| `getChatHistoryByChatId` | GET | `/service/chat/getChatHistoryByChatId` |
| `getPrompt` | GET | `/service/prompt/getPrompt` |
| `getPromptList` | GET | `/service/prompt/getPromptList` |
| `insertPrompt` | POST | `/service/prompt/insertPrompt` |
| `updatePrompt` | PUT | `/service/prompt/updatePrompt` |
| `deletePrompt` | DELETE | `/service/prompt/deletePrompt/{promptId}` |
| WebSocket | WS | `ws://127.0.0.1:4000/service/chat/ws/chat` |

### 5.6 全局状态 `AppState.shared`

已发布属性：`userData` / `token` / `isLoggedIn` / `currentCompany` / `currentTenant` / `currentModel` / `currentPrompt` / `tenantList` / `modelList`。

UserDefaults 缓存 key：

| key | 含义 |
|---|---|
| `auth_token` | 登录 token（由 `TokenManager` 读写） |
| `companyId_<userId>` | 按用户维度记住上次选的公司 |
| `current_tenant_id` | 当前租户 ID |
| `current_model_id` | 当前模型 ID |
| `current_prompt_id_<tenantId>` | 按租户维度记住选用的提示词 |

> `clearUserData()` 会清 token / 租户 / 模型缓存，但**故意不清** `companyId_<userId>`，用于切换账号后仍能记住各账号的公司。

### 5.7 角色权限口径

`role`：`2` 超级管理员 / `1` 管理员 / `0` 或 `nil` 普通成员。
状态 `status`：`0` 禁用 / `1` 启用 / `2` 停用（`TenantStatus` 枚举）。

典型门禁：`HomePage` 菜单中的「模型管理」仅当 `appState.currentCompany?.role ?? 0 > 0` 时出现。

---

## 六、数据模型清单（`Models/`）

| 模型 | 关键字段 | 说明 |
|---|---|---|
| `User` | id, userAccount, username, telephone, email, avater, birthday, sex, sign, region, role, disabled, permission | 用户主体，`var` 可变便于表单绑定 |
| `Company` | id, name, code, description, status, role | 公司；`isAdmin` / `isSuperAdmin` / `isNormalAdmin` / `isActive` |
| `Tenant` | id, name, code, description, status(`TenantStatus`), role | 租户；`roleText` / `shouldShowRoleTag` / `formattedCreateDate` |
| `CompanyUser` | userId, userAccount, username, departmentId/Name, positionId/Name, role, joinDate, status | 公司成员；`displayDepartment` / `displayPosition` / `roleText` |
| `TenantUser` | id, tenantId, tenantName, userId, userAccount, username, role, joinDate, disabled, email | 租户成员 |
| `SearchUserResult` | 同 User + `checked`(0/1) | 搜索结果，`isAdded` 表示是否已加入 |
| `Department` | id, companyId, departmentName, description, createTime | 部门（`getDepartments` 返回，添加公司成员时级联出职位） |
| `Position` | id, departmentId, positionName, description, createTime | 职位（`getPositions` 返回；添加成员只提交 `positionId`，后端由它反查部门） |
| `ChatModel` | id, modelName, type(`ollama`/`online`), baseUrl, apiKey, companyId, disabled | 大模型配置；`disabled` 0 启用 / 1 禁用，更新时原样回传 |
| `ChatModelType` | 枚举 `ollama` / `online` | 模型类型：`displayName` 中文文案、`requiresApiKey` 是否强制 API Key（新增/编辑模型页共用） |
| `Prompt` | id, tenantId, userId, prompt | 提示词 |
| `Directory` | id, userId, directory, tenantId | 知识库目录 |
| `Document` | id, name, ext, userId, directoryId, directoryName, checked | 知识库文档 |
| `ChatHistory` | id, chatId, prompt, thinkContent, responseContent, createTime, timeAgo | 单轮记录；`getFullAIResponse()` 拼 `<think>` + 正文；`calculateTimeAgo()` 算相对时间 |
| `ChatSessionGroup` | chatId, firstMessage, updateTime, timeAgo | 会话分组（会话列表用） |
| `ChatMessage` | id(UUID), content, isUser, timestamp | 内存态消息，不落库 |
| `ChatHistoryResponse` | total, list | 分页包装 |
| `BaseResponse<T>` | data, token, status, msg, total | 统一响应；`isSuccess` |
| `AppState` | 见 5.6 | 全局状态单例 |

---

## 七、如何使用这套文档（给 AI 的用法）

改动某个页面时，按顺序投喂：

1. `docs/README.md`（本文件）—— 全局规范、主题常量、接口表、状态与权限口径
2. `docs/pages/<目标页面>.md` —— 该页面的状态、视图树、方法、接口、坑
3. 若涉及后端字段：`/Users/wuwenqiang/Documents/code/python/fast-api-app-service/docs/api/<模块>.md`
4. 若需新增接口：一并给 `Config/Constants.swift`、`Api/APIEndpoints.swift`、`Network/HTTPClient.swift`

新增/维护文档时，先读 [`_共享上下文与文档模板.md`](_共享上下文与文档模板.md) 保持结构一致。
