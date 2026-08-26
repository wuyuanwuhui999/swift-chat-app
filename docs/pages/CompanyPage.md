---
name: company-page
description: 公司选择页（CompanyPage）。登录后选择所属公司（首次进入）或从 UserPage 切换公司；需要改公司选择/缓存策略/双入口逻辑时读这份文档。
page: CompanyPage.swift
path: chat/chat/UI/Pages/CompanyPage.swift
apis:
  - GET /service/company/getCompanyList
---

# CompanyPage（公司选择页）

## 1. 页面职责

`CompanyPage` 让用户从自己所属的公司列表中选中一家公司，作为后续聊天、租户、模型等资源的组织归属。它承担两个入口场景：

1. **首次登录选择公司**：`WelcomePage` 校验 token 通过后弹出本页（`fullScreenCover`），选择公司后跳转 `HomePage`。
2. **从 UserPage 切换公司**：`UserPage` 里再次打开本页（`isFromUserPage = true`），选择后 `dismiss` 返回 `UserPage`。

页面核心是「公司列表 + 单选卡片 + 底部确定按钮」，并把选中的公司写入全局状态与本地缓存。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/CompanyPage.swift`（约 319 行，含内嵌 `CompanyCard` 组件）
- **入口**：
  - 首次登录：`WelcomePage` 以 `fullScreenCover` 弹出。
  - 切换公司：`UserPage` 里以 `fullScreenCover` 弹出（本页通过 `appState.currentCompany != nil` 判断）。
- **出口**：
  - 首次登录 → `HomePage`（`navigationDestination(isPresented: $navigateToChat)`）
  - 切换公司 → `dismiss()` 返回
- **依赖组件**：内嵌 `CompanyCard`（同文件）
- **依赖模型**：`Company`
- **依赖服务**：`HTTPClient.shared.getCompanyList`、`AppState.shared`、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`AppState.shared`） | — | 全局状态，读写 `currentCompany`、`userData` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 关闭页面（切公司场景） |
| `companies` | `[Company]` | `[]` | 公司列表 |
| `selectedCompanyId` | `String?` | `nil` | 当前选中公司 ID |
| `isLoading` | `Bool` | `false` | 加载态 |
| `showAlert` | `Bool` | `false` | 错误提示弹窗 |
| `alertMessage` | `String` | `""` | 提示内容 |
| `navigateToChat` | `Bool` | `false` | 是否跳转 HomePage（首登） |
| `isFromUserPage` | `Bool` | `false` | 是否从 UserPage 进入（在 `loadCompanies` 里动态判定） |

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   ├─ customNavigationBar     高 50 / whiteColor / 底部 1px 分隔线（grayColor.opacity(0.3)）
   │    ├─ 返回按钮 chevron.left（仅 isFromUserPage 显示，否则 Color.clear 占位）
   │    ├─ 标题「选择公司」（middleFont）
   │    └─ 右侧 Color.clear 占位
   ├─ 内容区：
   │    ├─ isLoading → ProgressView(scaleEffect 1.5)
   │    ├─ companies.isEmpty → emptyStateView（building.2 图标 +「暂无公司信息」+「请先联系管理员添加公司」）
   │    └─ ScrollView → VStack(middleMargin) → ForEach(companies) { CompanyCard }
   ├─ Spacer(minLength: 0)
   └─ bottomButtonView         顶部 1px 分隔线 +「确定」按钮
├─ .background(Colors.pageBackgroundColor)
├─ .alert("提示", isPresented: $showAlert)
├─ .navigationDestination(isPresented: $navigateToChat) { HomePage().navigationBarHidden(true) }
└─ .onAppear { loadCompanies() }
└─ .navigationBarBackButtonHidden(true)
```

### 4.1 CompanyCard（同文件内嵌组件）

```
CompanyCard(company:isSelected:onSelect:)
└─ Button(action: onSelect)
   └─ HStack
      ├─ Text(company.name)  normalFont / black / lineLimit(1)
      ├─ Spacer
      └─ Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
           selected ? primaryColor : grayColor，middleIcon
   .padding(horizontal: middleMargin, vertical: middleMargin)
   .background(whiteColor).cornerRadius(borderRadius)
   .buttonStyle(PlainButtonStyle())
```

简化版单选卡片：只显示公司名 + 单选圆点，无公司描述/编码等附加信息。

### 4.2 bottomButtonView

`Button("确定")`：`btnHeight` 高、`btnHeight/2` 圆角、`maxWidth: .infinity`；选中态 `primaryColor` 底白字，未选中 `grayColor` 底且 `.disabled(selectedCompanyId == nil)`。上下 `middleMargin`，顶部 1px 分隔线。

## 5. 核心方法

### `loadCompanies()`
- **触发**：`onAppear`
- **步骤**：
  1. `isLoading = true`，取 `userId = AppState.shared.userData?.id`。
  2. 拼缓存 key `"companyId_\(userId)"`，从 `UserDefaults.standard` 读 `cachedCompanyId`（本页自己直接读 UserDefaults，不走 `AppState.getCachedCompanyId()`）。
  3. 判定入口：`if appState.currentCompany != nil { isFromUserPage = true }`。
  4. `getCompanyList { result in ... }`：
     - 成功：`companies = companyList`；确定目标公司 ID，优先级：
       1. `isFromUserPage` 且有 `currentCompany?.id` → 用它；
       2. 否则用 `cachedCompanyId`；
       3. 有目标 ID 但列表里匹配不到 → 打印「未找到匹配的公司」，需要手动选；
       4. `companyList.count == 1 && selectedCompanyId == nil` → 自动选中唯一一家。
     - 匹配成功 → `selectedCompanyId = matchedCompany.id` 自动选中。
     - 失败：`alertMessage = error.localizedDescription`，`showAlert = true`。
- **说明**：入口判定依赖「`currentCompany` 是否已存在」，而非显式传参。

### `saveSelectedCompany(_:)`
- **步骤**：
  1. `AppState.shared.saveCurrentCompany(company)`（**只写内存**，见 10.2）。
  2. 取 `userId`，拼 key `"companyId_\(userId)"`，`UserDefaults.standard.set(company.id, forKey: key)`（本页**独立写缓存**）。

### `handleConfirm()`
- **触发**：底部「确定」按钮。
- **步骤**：
  1. `guard` 取 `selectedCompanyId` 并在 `companies` 里找到对应 `Company`，否则 return。
  2. `saveSelectedCompany(selectedCompany)`。
  3. 分支：
     - `isFromUserPage` → `dismiss()`（返回 UserPage）。
     - 否则 → `navigateToChat = true`（首登跳 HomePage）。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getCompanyList` | GET | `/service/company/getCompanyList` | `onAppear` | `docs/api/company.md` |

### 6.1 getCompanyList

- **Swift 签名**：`func getCompanyList(completion: @escaping (Result<[Company], NetworkError>) -> Void)`
- **APIEndpoint**：`.getCompanyList`（GET）
- **请求**：无显式参数，鉴权走 `Authorization: Bearer`，网关注入 `X-User-Id` 后按用户查所属公司。
- **响应**：`BaseResponse<[Company]>.data`（公司列表）
- **UI 处理**：成功 → 填充 `companies` 并按缓存/当前公司自动选中；失败 → `alertMessage` + `showAlert`。

## 7. 数据模型

### 7.1 Company（`Models/Company.swift`）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 公司 ID |
| `name` | `String` | 否 | 公司名（卡片显示） |
| `code` | `String` | 否 | 公司编码 |
| `description` | `String?` | 是 | 描述 |
| `status` | `Int` | 否 | 0 禁用 / 1 启用 / 2 停用 |
| `createDate` / `updateDate` | `String?` | 是 | 时间 |
| `createdBy` | `String` | 否 | 创建人 |
| `updatedBy` | `String?` | 是 | 更新人 |
| `role` | `Int?` | 是 | 当前用户在公司角色（1 管理员 / 2 超管） |

便捷属性：`isActive`（status==1）、`isNormalAdmin`（role==1）、`isSuperAdmin`（role==2）、`isAdmin`（role 1 或 2）。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor`，高 50，底部 1px `grayColor.opacity(0.3)` 分隔线 |
| 卡片 | `Colors.whiteColor` + `Dimens.borderRadius` 圆角 |
| 单选圆点 | 选中 `Colors.primaryColor`，未选中 `Colors.grayColor` |
| 确定按钮 | 选中 `Colors.primaryColor`，禁用 `Colors.grayColor`，高 `Dimens.btnHeight`，圆角 `btnHeight/2` |
| 返回箭头 | `Colors.primaryColor`，`Dimens.middleIcon` |
| 空状态 | `Colors.grayColor` 图标 + 文字 |

## 9. 交互流程

### 9.1 首次登录选公司

```
WelcomePage(fullScreenCover) → CompanyPage
  onAppear → loadCompanies()
    → 判定 isFromUserPage（currentCompany == nil → false）
    → getCompanyList
    → 优先用缓存 companyId 匹配选中；否则单公司自动选中
  用户点「确定」→ handleConfirm
    → saveSelectedCompany（内存 + UserDefaults）
    → navigateToChat = true → navigationDestination 推 HomePage
```

### 9.2 从 UserPage 切换公司

```
UserPage → CompanyPage（fullScreenCover）
  onAppear → loadCompanies()
    → currentCompany != nil → isFromUserPage = true（导航栏显示返回箭头）
    → 优先用 currentCompany.id 匹配选中
  用户点「确定」→ handleConfirm
    → saveSelectedCompany（覆盖内存 + 缓存）
    → isFromUserPage → dismiss() 返回 UserPage
```

### 9.3 缓存策略（companyId_<userId>）

- 写入：仅 `CompanyPage.saveSelectedCompany` 用 `UserDefaults.set("companyId_\(userId)")`。
- 读取：`CompanyPage.loadCompanies` 自己读；`AppState.getCachedCompanyId()` 也读同一 key（HomePage 取公司 ID 时用）。
- 清理：`AppState.clearCompanyCache()` 会 `removeObject` 该 key 并清 `currentCompany`；`clearUserData()` **不清**公司缓存（注释说明「切换账号时需要」）。

## 10. 二次开发指引

- **改文案/样式**：空状态 → `emptyStateView`；卡片 → `CompanyCard`；按钮 → `bottomButtonView`。
- **改入口判定**：`isFromUserPage` 目前靠 `currentCompany != nil` 隐式推断，建议改为显式传参（构造参数或 `@Binding`），否则「已选过公司但重新登录」等场景会误判。
- **加字段**：`Company` 模型 → `getCompanyList` 解码 → `CompanyCard` 展示，三处同步。

### 10.1 已知坑

1. **注释与实现不符**：`handleConfirm` 里注释写「修复：直接使用 fullScreenCover 方式跳转，而不是 navigationDestination」，但代码实际仍用 `navigationDestination(isPresented: $navigateToChat)`。
2. **`saveCurrentCompany` 只存内存**：`AppState.saveCurrentCompany(_:)` 仅 `self.currentCompany = company`，不写 UserDefaults；`companyId_<userId>` 缓存由本页 `saveSelectedCompany` 独立写。两处职责分离，若后续只调 `AppState.saveCurrentCompany` 而忘记写缓存，`getCachedCompanyId()` 会拿不到。
3. **入口判定依赖隐式状态**：`isFromUserPage` 由「`currentCompany` 是否已存在」推断，而非显式来源参数；首次进入且之前已有缓存的公司时（`currentCompany` 为 nil 但 `cachedCompanyId` 有值）会走首登分支。
4. **`selectedCompanyId` 无显式重置**：`loadCompanies` 里自动选中只发生在 `selectedCompanyId == nil` 时；页面复用（如第二次进入）时旧的 `@State` 可能残留，需注意。
5. **返回箭头首帧闪烁**：`isFromUserPage` 在 `onAppear` 的 `loadCompanies` 里才置 `true`，首帧渲染时导航栏先显示无返回箭头（占位 `Color.clear`），随后才补上。

## 相关文档

- [HomePage](HomePage.md)（首登跳转目标）
- 后端接口：`docs/api/company.md`
