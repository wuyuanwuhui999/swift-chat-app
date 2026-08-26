---
name: user-manage-page
description: 用户管理页（UserManagePage）。管理当前**公司**的成员（CompanyUser）：分页列表 + 防抖搜索 + 点击进成员详情 + 跳转添加成员；需要改公司成员列表、搜索或成员详情入口时读这份文档。
page: UserManagePage.swift
path: chat/chat/UI/Pages/UserManagePage.swift
apis:
  - GET /service/company/getCompanyUsers
---

# UserManagePage（用户管理页 / 公司成员管理）

## 1. 页面职责

`UserManagePage` 管理**当前公司**（`AppState.shared.currentCompany`，缺失时回退到 `getCachedCompanyId()`）下的成员：分页展示成员列表、按姓名或工号防抖搜索、点击某行进入只读的成员详情页，并提供「+」入口跳转到 [AddCompanyUserPage](AddCompanyUserPage.md) 把用户加入公司。

尽管页面标题是「用户管理」，它的数据模型是 `CompanyUser`、接口是 `/service/company/getCompanyUsers`，**管的是公司维度的成员**。租户维度的成员管理是另一条线，见 [TenantManagePage](TenantManagePage.md)。

本页是纯只读 + 导航型页面：没有删除、没有改角色（后端虽有 `updateUserRole` / `removeUser`，客户端未接入）。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/UserManagePage.swift`（约 430 行，含内嵌 `UserManageRow` 组件）
- **入口**：[UserPage](UserPage.md) 的「用户管理」按钮 → `.fullScreenCover(isPresented: $navigateToUserManagePage) { UserManagePage() }`
  - `UserPage` 里有**两个**都指向 `navigateToUserManagePage` 的「用户管理」按钮，条件分别是 `appState.currentCompany?.isAdmin`（role 1 或 2）与 `company.role ?? 0 > 1`（role 2），见 10.1。
- **出口**：
  - `AddCompanyUserPage()` —— `.navigationDestination(isPresented: $navigateToAddUser)`，目标页加 `.navigationBarHidden(true)`
  - `UserInfoPage(companyUser:)` —— `.navigationDestination(isPresented: $showUserInfoPage)`，内部 `if let user = selectedUser`，目标页加 `.navigationBarHidden(true)`
  - `dismiss()` —— 返回 [UserPage](UserPage.md)
- **依赖组件**：`UI/Components/UserAvatar.swift`、同文件内嵌 `UserManageRow`
- **依赖模型**：`Models/CompanyUser.swift`
- **依赖服务**：`HTTPClient.shared.getCompanyUsers`、`AppState.shared`（`currentCompany`、`getCachedCompanyId()`）、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentCompany` / 公司缓存 |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 关闭页面 |
| `users` | `@State [CompanyUser]` | `[]` | 公司成员主列表 |
| `isLoading` | `@State Bool` | `false` | 首屏/重置加载态 |
| `isLoadingMore` | `@State Bool` | `false` | 加载更多中 |
| `currentPage` | `@State Int` | `1` | 当前页码 |
| `hasMoreData` | `@State Bool` | `true` | 是否还有下一页 |
| `pageSize` | `@State Int` | `20` | 每页条数（全程未修改） |
| `searchText` | `@State String` | `""` | 搜索关键词 |
| `isSearching` | `@State Bool` | `false` | 是否处于搜索模式 |
| `searchResults` | `@State [CompanyUser]` | `[]` | 搜索结果 |
| `isSearchLoading` | `@State Bool` | `false` | 搜索请求中 |
| `searchWorkItem` | `@State DispatchWorkItem?` | `nil` | 防抖任务句柄 |
| `showAlert` | `@State Bool` | `false` | 提示弹窗 |
| `alertMessage` | `@State String` | `""` | 提示内容 |
| `navigateToAddUser` | `@State Bool` | `false` | 是否跳 `AddCompanyUserPage` |
| `selectedUser` | `@State CompanyUser?` | `nil` | 点击选中的成员（传给 `UserInfoPage`） |
| `showUserInfoPage` | `@State Bool` | `false` | 是否跳 `UserInfoPage` |
| `isRefreshing` | `@State Bool` | `false` | 下拉刷新中 |

本页**没有**任何角色计算属性（对比 [TenantManagePage](TenantManagePage.md) 的 `tenantUserRole`）。

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   ├─ customNavigationBar        背景 whiteColor / 内边距 middleMargin / 底部 1px grayColor.opacity(0.3)
   │    ├─ 返回 chevron.left     middleIcon / subColor → dismiss()
   │    ├─ 标题「用户管理」       middleFont / .black
   │    └─ 「plus」按钮          middleIcon / subColor → navigateToAddUser = true（无权限判断）
   ├─ searchBarView              胶囊输入框：高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
   │    ├─ magnifyingglass       smallIcon / grayColor
   │    ├─ TextField「搜索用户（姓名或工号）」 onChange → handleSearchTextChange
   │    └─ !searchText.isEmpty → xmark.circle.fill
   │    外层 padding(.vertical, Dimens.smallIcon) + 底部 1px grayColor.opacity(0.3)
   └─ ScrollView                 背景 pageBackgroundColor / .refreshable { await refreshData() }
      └─ VStack(spacing: middleMargin) → userListCardView
           卡片：background(whiteColor) + cornerRadius(borderRadius)
           ├─ isLoading                                    → ProgressView（vertical largeMargin）
           ├─ (isSearching ? searchResults : users).isEmpty → emptyStateView
           └─ else                                         → userListView
.background(Colors.pageBackgroundColor)
.alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
.onAppear { loadCompanyUsers() }
.navigationDestination(isPresented: $navigateToAddUser) { AddCompanyUserPage().navigationBarHidden(true) }
.navigationDestination(isPresented: $showUserInfoPage) {
    if let user = selectedUser { UserInfoPage(companyUser: user).navigationBarHidden(true) }
}
```

### 4.1 userListView

```
let displayUsers = isSearching ? searchResults : users

LazyVStack(spacing: 0)
├─ ForEach(displayUsers.enumerated(), id: \.element.id)
│    ├─ UserManageRow(companyUser: user)
│    │     .onTapGesture { selectedUser = user; showUserInfoPage = true }
│    └─ index < displayUsers.count - 1 → Divider().padding(.leading, middleMargin)
├─ !isSearching && hasMoreData && !isLoadingMore && !isRefreshing
│    → ProgressView().onAppear { loadMoreUsers() }      // 触底加载更多
└─ isSearching && isSearchLoading → ProgressView()      // 搜索纯 loading，不分页
```

### 4.2 emptyStateView

`person.slash`（`bigIcon` / `grayColor`）+ `isSearching ? "未找到相关用户" : "暂无用户"`（`normalFont` / `grayColor`），垂直 `largeMargin`。

### 4.3 UserManageRow（同文件内嵌）

```
VStack(alignment: .leading, spacing: Dimens.smallMargin)
└─ HStack(spacing: Dimens.middleMargin)
   ├─ UserAvatar(avatarUrl: companyUser.avater, username: companyUser.username, size: middleAvater)
   ├─ VStack(alignment: .leading, spacing: Dimens.middleMargin)
   │    ├─ HStack(spacing: Dimens.middleMargin)
   │    │    ├─ Text(companyUser.username)   normalFont / .black
   │    │    └─ companyUser.shouldShowRoleTag → Text(companyUser.roleText)
   │    │         normalFont-4 / primaryColor / 背景 primaryColor.opacity(0.1) / 圆角 smallIcon
   │    └─ Text(companyUser.userAccount)     normalFont-2 / grayColor
   └─ Spacer
.padding(.horizontal, middleMargin).padding(.vertical, middleMargin)
.contentShape(Rectangle())        // 保证整行可点击
```

组件文档注释写的是「显示用户头像、姓名、角色标签、部门名称、职位名称」，但**部门与职位实际没有渲染**（见 10.1）。

## 5. 核心方法

### `handleSearchTextChange(_ newValue: String)`
- **触发**：搜索框 `.onChange(of: searchText)`
- **步骤**：
  1. `searchWorkItem?.cancel()`。
  2. 空串 → `isSearching = false`、`searchResults = []`，return（回到主列表）。
  3. 非空 → 建 `DispatchWorkItem { performSearch(keyword: newValue) }`，`asyncAfter(.now() + 0.5)`（0.5s 防抖）。

### `performSearch(keyword: String)`
- **触发**：防抖任务、`refreshData()` 中搜索态刷新
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { print("❌ 未找到公司ID"); return }`。
  2. `isSearching = true`、`isSearchLoading = true`。
  3. 调 `getCompanyUsers(companyId:keyword:pageNum: 1, pageSize: 100)`（**复用列表接口**，非 `searchCompanyUsers`）。
  4. 主线程回调：`isSearchLoading = false`；成功 → `searchResults = users`；失败 → `print` + 清空 `searchResults`（**不弹 alert**）。

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：
  1. `MainActor.run { isRefreshing = true }`。
  2. `currentPage = 1`、`hasMoreData = true`。
  3. `isSearching` → `searchText` 非空时 `performSearch(keyword: searchText)`；否则 `loadCompanyUsers(reset: true)`。
  4. `MainActor.run { isRefreshing = false }`。
- **注意**：不等待网络回调（见 10.1）。

### `loadCompanyUsers(reset: Bool = true)`
- **触发**：`onAppear`（默认 `reset = true`）、`refreshData()`、`loadMoreUsers()`（`reset = false`）
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { print("❌ 未找到公司ID"); return }`。
  2. `reset` → `isLoading = true`、`currentPage = 1`、`users = []`、`hasMoreData = true`。
  3. 调 `getCompanyUsers(companyId:pageNum: currentPage, pageSize: pageSize)`。
  4. 主线程回调：`isLoading = false`、`isLoadingMore = false`。
     - 成功：`reset` → 整体替换；否则用 `Set(users.compactMap { $0.id })` 去重后 `append`（`id` 为 nil 的条目被过滤掉）；`hasMoreData = users.count < total`。
     - 失败：`alertMessage = error.localizedDescription`、`showAlert = true`。

### `loadMoreUsers()`
- **触发**：列表底部 `ProgressView.onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData && !isSearching` → `isLoadingMore = true` → `currentPage += 1` → `loadCompanyUsers(reset: false)`。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getCompanyUsers` | GET | `/service/company/getCompanyUsers` | `onAppear` / 加载更多 / 下拉刷新 / 搜索 | `docs/api/company.md` §2 |

### 6.1 getCompanyUsers

- **Swift 签名**：
  ```swift
  func getCompanyUsers(companyId: String, keyword: String? = nil, pageNum: Int, pageSize: Int,
                       completion: @escaping (Result<([CompanyUser], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.getCompanyUsers` 存在（GET / `Constants.API.getCompanyUsers = "/service/company/getCompanyUsers"`），但该方法**没走** `request(endpoint:)`，而是自己 `URLComponents(string: baseURL + Constants.API.getCompanyUsers)` 拼 URL、手动设 `Content-Type` 与 `Authorization`。
- **请求**：

  | 名称 | 位置 | 类型 | 必填 | 说明 |
  |---|---|---|---|---|
  | `companyId` | Query | String | 是 | 公司 ID |
  | `pageNum` | Query | Int | 是 | 页码 |
  | `pageSize` | Query | Int | 是 | 列表 20 / 搜索 100 |
  | `keyword` | Query | String | 否 | 非空才拼入（姓名或工号） |

- **响应**：`BaseResponse<[CompanyUser]>`，`total` 为总数（缺失时按 `0` 处理）。后端文档 §2 出参示例是 `{"id","userId","companyId","role":"1","positionId","isDefault","status"}`，其中 `role` 是字符串且有客户端模型里不存在的 `isDefault`，而客户端 `CompanyUser.role` 是 `Int?`、还额外解 `username/userAccount/telephone/email/sex/positionName/departmentName/...`。**两边不完全对齐，实际以客户端解码结构为准**（后端文档示例未覆盖全部字段）。
- **UI 处理**：成功 → 填 `users` 或 `searchResults`、更新 `hasMoreData`；列表失败 → alert；搜索失败 → 仅 `print`。
- **权限**：后端文档标注「需企业管理员权限」，客户端不做前置校验，仅靠 [UserPage](UserPage.md) 的入口按钮条件控制。

## 7. 数据模型

### 7.1 CompanyUser（`Models/CompanyUser.swift`，对应后端 `CompanyUserEntity`）

本页真正用到的字段：

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String?` | 是 | 关联记录 ID，作 `ForEach` 的 identity |
| `userId` | `String?` | 是 | 用户 ID（本页未使用，`UserInfoPage` 可用） |
| `username` | `String` | 否 | 昵称（行标题） |
| `userAccount` | `String` | 否 | 工号（行副标题） |
| `avater` | `String?` | 是 | 头像相对路径 |
| `role` | `Int?` | 是 | 2 超级管理员 / 1 管理员 / 0 普通成员 |

模型其余字段（`telephone`、`email`、`sex`、`region`、`sign`、`companyId`、`positionId`、`positionName`、`departmentId`、`departmentName`、`joinDate`、`status`、`createBy`、`createDate`、`updateDate`、`birthday`、`password`、`disabled`、`permission`）本页不展示，但会整个对象传给 [UserInfoPage](UserInfoPage.md)。

便捷属性：

- `roleText`：2→「超级管理员」/ 1→「管理员」/ 其他（含 nil）→「普通成员」
- `shouldShowRoleTag`：`(role ?? 0) > 0`
- `displayDepartment` = `departmentName ?? "未分配"`、`displayPosition` = `positionName ?? "未分配"`（**本页均未使用**）

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor`，内边距 `Dimens.middleMargin`，底部 1px `Colors.grayColor.opacity(0.3)` |
| 返回 / 添加图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont` / `.black` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，背景 `whiteColor`，描边 `grayColor.opacity(0.5)` |
| 搜索栏容器 | 水平 `middleMargin`，垂直 `Dimens.smallIcon`，底部 1px `grayColor.opacity(0.3)` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 头像 | `Dimens.middleAvater` |
| 用户名 / 工号 | `Dimens.normalFont` `.black` / `Dimens.normalFont - 2` `Colors.grayColor` |
| 角色标签 | `Dimens.normalFont - 4`，`Colors.primaryColor`，背景 `primaryColor.opacity(0.1)`，圆角 `Dimens.smallIcon` |
| 行内边距 | 水平/垂直均 `Dimens.middleMargin`；行内 `VStack` spacing 用 `Dimens.smallMargin` / `Dimens.middleMargin` |
| 分隔线 | `Divider().padding(.leading, Dimens.middleMargin)` |
| 空状态 | `person.slash` `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入页面 → 分页列表

```
UserPage 点「用户管理」（company.isAdmin 或 company.role > 1）
  → fullScreenCover → UserManagePage
     onAppear → loadCompanyUsers(reset: true)
        companyId = currentCompany?.id ?? getCachedCompanyId()（都取不到只 print 并 return）
        → GET getCompanyUsers(companyId, pageNum: 1, pageSize: 20)
        → users 填充；hasMoreData = users.count < total
     列表底部 ProgressView.onAppear → loadMoreUsers()
        → currentPage += 1 → loadCompanyUsers(reset: false)（compactMap 去重 append）
```

### 9.2 搜索（0.5s 防抖）

```
输入 → onChange → handleSearchTextChange
  空串   → isSearching = false，searchResults 清空，回到主列表（主列表数据保留）
  非空串 → 取消旧 WorkItem，0.5s 后 performSearch(keyword:)
             → GET getCompanyUsers(keyword, pageNum: 1, pageSize: 100)
             → isSearching = true，searchResults = users（无分页、失败不提示）
```

### 9.3 查看成员详情

```
点击任意行（UserManageRow 已加 .contentShape(Rectangle())，整行可点）
  → selectedUser = user；showUserInfoPage = true
  → navigationDestination 推 UserInfoPage(companyUser: user)（只读详情，见 UserInfoPage.md）
  → 返回后 showUserInfoPage 置回 false，selectedUser 仍保留上次值
```

### 9.4 添加成员

```
点导航栏「plus」→ navigateToAddUser = true
  → navigationDestination 推 AddCompanyUserPage（搜索用户 + 选部门/职位/角色 → POST /service/company/addUser）
  → 返回本页后不会自动刷新，需要下拉刷新才能看到新成员
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 → `customNavigationBar`；搜索框 → `searchBarView`；空态 → `emptyStateView`；行样式 → `UserManageRow.body`。
- **补部门/职位展示**：`CompanyUser` 已有 `displayDepartment` / `displayPosition`，直接在 `UserManageRow` 的内层 `VStack` 里加一行即可，无需改模型和接口。
- **加字段**：`Models/CompanyUser.swift`（含 `CodingKeys`）→ `getCompanyUsers` 解码 → `UserManageRow` 展示 →（若详情页也要用）[UserInfoPage](UserInfoPage.md)。
- **加接口**（如接入后端已有的改角色/移除成员）：`Constants.API` 新增 `updateUserRole = "/service/company/updateUserRole"`、`removeUser = "/service/company/removeUser"` → `APIEndpoint` 加 case + `method`（PUT / DELETE）→ `HTTPClient` 方法 → 页面加左滑或详情页操作。注意 `removeUser` 后端要求 Body（`RemoveUserSchema`）而非 Path 参数。

### 10.1 已知坑

1. **UserPage 里有两个重复的「用户管理」按钮**：`UserPage.swift` 第 183 行（`company.isAdmin`，role 1 或 2）与第 223 行（`company.role ?? 0 > 1`，role 2）都设置 `navigateToUserManagePage = true`，文案与样式完全相同。**超级管理员会看到两个一模一样的「用户管理」按钮**，第二个是冗余代码。
2. **「+」按钮无权限判断**：本页导航栏的 `plus` 无条件显示（对比 [TenantManagePage](TenantManagePage.md) 的 `if tenantUserRole >= 1`），只要能进入本页就能进添加页。当前靠 `UserPage` 的入口条件兜底，属于薄弱防线。
3. **`UserManageRow` 注释与实现不符**：组件文档注释写「显示用户头像、姓名、角色标签、部门名称、职位名称」，实际 body 里只渲染头像 / 用户名 / 角色标签 / `userAccount`，`displayDepartment`、`displayPosition` 一次都没用。
4. **`UserManageRow` 结构有冗余**：最外层 `VStack(alignment: .leading, spacing: Dimens.smallMargin)` 只包了一个 `HStack`；`HStack` 末尾 `Spacer` 之后还留着两行空白（原本预留的尾部内容被删掉了），可以直接简化。
5. **`ForEach(id: \.element.id)` 的 id 是 `String?`**：`CompanyUser.id` 可选，若后端返回 nil，多条 nil 会共用同一 identity，导致行复用错乱；`loadCompanyUsers` 的去重也用 `compactMap { $0.id }`，nil id 的条目每次分页都会被重复 append。
6. **搜索没有走 `searchCompanyUsers`**：本页搜索复用 `getCompanyUsers(keyword:)`，`pageSize` 写死 `100` 且**不支持加载更多**（`isSearching` 时只显示 loading 圈），公司成员超 100 人时搜索结果会被截断。`searchCompanyUsers`（`/service/company/searchUsers`）只在 [AddCompanyUserPage](AddCompanyUserPage.md) 使用，两者语义不同：前者查「已在公司的成员」，后者查「可加入公司的用户」。
7. **搜索失败静默**：`performSearch` 的 `.failure` 只 `print` 并清空结果，UI 显示「未找到相关用户」，无法区分请求失败。
8. **`refreshData()` 的 async 时序错位**：内部调用回调式方法后立刻 `MainActor.run { isRefreshing = false }`，下拉刷新 spinner 会在数据回来前消失；`currentPage` / `hasMoreData` 也在非 MainActor 上下文被直接改写。
9. **`hasMoreData` 依赖 `total`**：`total` 缺失时 `HTTPClient` 兜底 `0`，`users.count < 0` 为 false → 立即判定没有更多，只显示第一页。
10. **加载更多失败不回滚页码**：`loadMoreUsers` 先 `currentPage += 1` 再请求，失败后页码不退回，会跳页漏数据。
11. **`showUserInfoPage` 与 `selectedUser` 解耦不彻底**：`navigationDestination` 内是 `if let user = selectedUser`，若在 `selectedUser` 被清空/未赋值的情况下把 `showUserInfoPage` 置 true，会 push 一个空白页。推荐改成 `navigationDestination(item:)` 或 `.sheet(item:)` 的 `Identifiable` 形式。
12. **从添加页返回不刷新**：`AddCompanyUserPage` 添加成功后本页 `users` 不会更新（`onAppear` 在 `NavigationStack` push/pop 时不一定重新触发），需用户手动下拉刷新。
13. **无删除/改角色能力**：后端已提供 `PUT /service/company/updateUserRole` 与 `DELETE /service/company/removeUser`（`docs/api/company.md` §5、§6），但 `Constants.API` / `APIEndpoint` / `HTTPClient` 均无对应定义，本页也没有左滑操作。
14. **`[self]` capture list 无意义**：`loadCompanyUsers` 里写了 `{ [self] result in ... }`，而 `UserManagePage` 是 struct（值类型），该捕获列表不产生效果。
15. **间距用了图标常量**：搜索栏 `padding(.vertical, Dimens.smallIcon)`，按样式铁律应为 `Dimens.middleMargin`（数值同为 15）。
16. **`pageSize` 用 `@State` 但从不变化**：可改为 `let`。

## 相关文档

- [UserPage](UserPage.md)（入口，含两个重复按钮）
- [AddCompanyUserPage](AddCompanyUserPage.md)（出口：把用户加入公司）
- [UserInfoPage](UserInfoPage.md)（出口：公司成员只读详情）
- [TenantManagePage](TenantManagePage.md)（租户成员管理，另一条线）
- 后端接口：`docs/api/company.md`
