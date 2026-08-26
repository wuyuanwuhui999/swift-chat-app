---
name: add-tenant-user-page
description: 添加租户用户页（AddTenantUserPage）。搜索公司内用户并一键加入当前租户，带防抖搜索、分页加载、已添加状态标记；需要改租户成员添加流程或搜索分页时读这份文档。
page: AddTenantUserPage.swift
path: chat/chat/UI/Pages/AddTenantUserPage.swift
apis:
  - GET /service/tenant/searchTenantUsers
  - GET /service/tenant/getTenantUserList
  - POST /service/tenant/addTenantUser/{tenantId}/{userId}
---

# AddTenantUserPage（添加租户用户页）

## 1. 页面职责

`AddTenantUserPage` 负责把用户加入**当前租户**：输入姓名或工号搜索（在当前公司范围内），列表逐条展示搜索结果，点「添加」直接调接口把该用户挂到当前租户下。

页面进入时会先拉一次租户成员全量列表，把已在租户中的用户 ID 缓存起来，用于把行内按钮显示为「已添加」灰标签，避免重复添加。

它是 [TenantManagePage](TenantManagePage.md) 的下级页面，不做角色/部门配置——加入租户后的角色默认由后端决定，管理员权限要回 [TenantManagePage](TenantManagePage.md) 左滑设置。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/AddTenantUserPage.swift`（约 419 行）
- **入口**：[TenantManagePage](TenantManagePage.md) 导航栏「plus」按钮 → `.navigationDestination(isPresented: $navigateToAddUser) { AddTenantUserPage().navigationBarHidden(true) }`（父页在 `NavigationStack` 内）
- **出口**：仅 `dismiss()` 返回 [TenantManagePage](TenantManagePage.md)，无其他跳转
- **依赖组件**：`UI/Components/UserAvatar.swift`、`UI/Components/UserSearchRow.swift`（与 [AddCompanyUserPage](AddCompanyUserPage.md) 共用的公共行组件）
- **依赖模型**：`Models/SearchUserResult.swift`（搜索结果）、`Models/TenantUser.swift`（间接：`getTenantUserList` 的解码类型）
- **依赖服务**：`HTTPClient.shared.searchTenantUsers`、`HTTPClient.shared.getTenantUserList`、`HTTPClient.shared.addTenantUser`、`AppState.shared`（`currentTenant`、`currentCompany`、`getCachedCompanyId()`）、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentTenant` / `currentCompany` / 公司缓存 |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 返回上一页 |
| `searchText` | `@State String` | `""` | 搜索关键词 |
| `searchResults` | `@State [SearchUserResult]` | `[]` | 搜索结果列表 |
| `isSearchLoading` | `@State Bool` | `false` | 搜索请求中 |
| `searchWorkItem` | `@State DispatchWorkItem?` | `nil` | 防抖任务句柄 |
| `currentPage` | `@State Int` | `1` | 搜索分页页码 |
| `pageSize` | `@State Int` | `20` | 每页条数（全程未修改） |
| `hasMoreData` | `@State Bool` | `true` | 是否还有下一页 |
| `isLoadingMore` | `@State Bool` | `false` | 加载更多中 |
| `addedUserIds` | `@State Set<String>` | `[]` | 已在租户中的 **userId** 集合 |
| `addingUserIds` | `@State Set<String>` | `[]` | 正在添加中的用户 ID（行内转圈） |
| `showAlert` | `@State Bool` | `false` | 提示弹窗 |
| `alertMessage` | `@State String` | `""` | 提示内容 |
| `isRefreshing` | `@State Bool` | `false` | 下拉刷新中 |

本页**没有**计算属性，权限判断全部在父页 [TenantManagePage](TenantManagePage.md) 完成。

## 4. 视图结构

```
body: VStack(spacing: 0)          ← 无 NavigationStack，复用父页的栈
├─ customNavigationBar            背景 whiteColor / 内边距 middleMargin / 底部 1px Colors.grayColor
│    ├─ 返回 chevron.left         middleIcon / subColor → dismiss()
│    ├─ 标题「添加用户」           middleFont / .black
│    └─ 占位 Button(chevron.left) foregroundColor(.clear) + .disabled(true)
├─ searchBarView                  胶囊输入框，高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
│    ├─ magnifyingglass          smallIcon / grayColor
│    ├─ TextField「搜索用户（姓名或工号）」 onChange → handleSearchTextChange
│    └─ !searchText.isEmpty → xmark.circle.fill
│    外层 padding(.vertical, Dimens.smallIcon) + 底部 1px grayColor.opacity(0.3)
└─ ScrollView                     背景 pageBackgroundColor / .refreshable { await refreshData() }
   └─ VStack(spacing: middleMargin) → userListCardView
        卡片：background(whiteColor) + cornerRadius(borderRadius)
        ├─ isSearchLoading && searchResults.isEmpty        → ProgressView（vertical largeMargin）
        ├─ searchResults.isEmpty && !searchText.isEmpty    → emptyStateView（未找到）
        ├─ searchResults.isEmpty                           → emptySearchView（未搜索引导）
        └─ else                                            → userListView
.background(Colors.pageBackgroundColor)
.alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
.onAppear { loadAddedUsers() }
.navigationBarHidden(true)
```

### 4.1 userListView

```
LazyVStack(spacing: 0)
├─ ForEach(searchResults.enumerated(), id: \.element.id)
│    ├─ UserSearchRow(user:isAdded:isAdding:onAdd:)
│    │    isAdded  = addedUserIds.contains(user.id ?? "")
│    │    isAdding = addingUserIds.contains(user.id ?? "")
│    │    onAdd    = { addUserToTenant(user) }
│    └─ index < searchResults.count - 1 → Divider().padding(.leading, middleMargin)
└─ hasMoreData && !isLoadingMore && !isRefreshing && !searchText.isEmpty
     → ProgressView().onAppear { loadMoreUsers() }
```

### 4.2 两种空状态

| 视图 | 触发条件 | 内容 |
|---|---|---|
| `emptyStateView` | `searchResults.isEmpty && !searchText.isEmpty` | `person.slash`（`bigIcon`/`grayColor`）+「未找到相关用户」（`normalFont`）+「请尝试其他关键词」（`normalFont - 2`） |
| `emptySearchView` | `searchResults.isEmpty`（且 `searchText` 为空） | `magnifyingglass`（`bigIcon`/`grayColor`）+「输入姓名或工号搜索用户」（`normalFont`） |

### 4.3 UserSearchRow（`UI/Components/UserSearchRow.swift`，与 [AddCompanyUserPage](AddCompanyUserPage.md) 共用）

```
HStack(spacing: Dimens.middleMargin)
├─ UserAvatar(avatarUrl: user.avater, username: user.username, size: middleAvater)
├─ VStack(alignment: .leading, spacing: Dimens.smallIcon)
│    ├─ Text(user.username)     normalFont / .black
│    └─ Text(user.userAccount)  normalFont - 2 / grayColor
├─ Spacer
└─ 尾部三态：
     isAdded  → Text("已添加")  normalFont-2 / grayColor / 背景 grayColor.opacity(0.2) / 圆角 borderRadius*2
     isAdding → ProgressView().frame(width: middleIcon, height: middleIcon)
     else     → Button("添加")  normalFont / 白字 / 背景 primaryColor / 圆角 borderRadius*2
.padding(.horizontal, middleMargin).padding(.vertical, middleMargin)
```

按钮内边距为 `horizontal: middleMargin` + `vertical: Dimens.smallMargin`。

## 5. 核心方法

### `handleSearchTextChange(_ newValue: String)`
- **触发**：搜索框 `.onChange(of: searchText)`
- **步骤**：
  1. `searchWorkItem?.cancel()`。
  2. 空串 → `searchResults = []`、`hasMoreData = true`、`currentPage = 1` 后 return。
  3. 非空 → 先重置分页（`currentPage = 1`、`hasMoreData = true`、`searchResults = []`），再建 `DispatchWorkItem { performSearch(reset: true) }`，`asyncAfter(.now() + 0.5)` 执行。

### `performSearch(reset: Bool = true)`
- **触发**：防抖任务、`loadMoreUsers()`（`reset = false`）、`refreshData()`
- **步骤**：
  1. `guard !searchText.isEmpty else { return }`。
  2. `guard let tenantId = appState.currentTenant?.id else { print("❌ 未找到租户ID"); return }`。
  3. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { print("❌ 未找到公司ID"); return }`。
  4. `reset` → `isSearchLoading = true`、`currentPage = 1`、`searchResults = []`。
  5. 调 `searchTenantUsers(tenantId:companyId:keyword: searchText, pageNum: currentPage, pageSize: pageSize)`。
  6. 主线程回调：`isSearchLoading = false`、`isLoadingMore = false`。
     - 成功：`reset` → 整体替换；否则用 `Set(searchResults.compactMap { $0.id })` 去重后 `append`（`id` 为 nil 的条目会被过滤掉）；`hasMoreData = searchResults.count < total`。
     - 失败：`print`，且仅在 `reset` 时把 `searchResults` 清空（**不弹 alert**）。

### `loadMoreUsers()`
- **触发**：列表底部 `ProgressView.onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData && !searchText.isEmpty` → `isLoadingMore = true` → `currentPage += 1` → `performSearch(reset: false)`。

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：`MainActor.run { isRefreshing = true }` → `searchText` 非空时 `performSearch(reset: true)` → `MainActor.run { isRefreshing = false }`。
- **注意**：不等待网络回调（见 10.1）。

### `loadAddedUsers()`
- **触发**：`.onAppear`
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id else { return }`。
  2. 调 `getTenantUserList(tenantId:pageNum: 1, pageSize: 1000)` 拉「全量」租户成员。
  3. 成功 → `addedUserIds = Set(users.map { $0.userId })`（注意取的是 `userId`，与搜索结果的 `SearchUserResult.id` 同为用户 ID，可正确比对）。
  4. 失败 → 仅 `print("❌ 获取已添加用户列表失败: ...")`。

### `addUserToTenant(_ user: SearchUserResult)`
- **触发**：行内「添加」按钮
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id, let userId = user.id else { return }`。
  2. `guard !addingUserIds.contains(userId) else { return }` 防重复点击。
  3. `addingUserIds.insert(userId)`（该行变 `ProgressView`）。
  4. 调 `addTenantUser(tenantId:userId:)`。
  5. 主线程回调先 `addingUserIds.remove(userId)`，再分支：
     - `data > 0` → `alertMessage = "添加成功"`、`showAlert = true`、`addedUserIds.insert(userId)`（该行变「已添加」）。
     - `data <= 0` → 「添加失败，请稍后重试」。
     - `.failure` → `error.localizedDescription`。
- **注意**：成功后**不重新搜索**，只做本地乐观更新。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getTenantUserList` | GET | `/service/tenant/getTenantUserList` | `onAppear`（`pageSize: 1000`） | `docs/api/tenant.md` §3 |
| 2 | `searchTenantUsers` | GET | `/service/tenant/searchTenantUsers` | 防抖搜索 / 加载更多 / 下拉刷新 | `docs/api/tenant.md` §12 |
| 3 | `addTenantUser` | POST | `/service/tenant/addTenantUser/{tenantId}/{userId}` | 行内「添加」 | `docs/api/tenant.md` §7 |

### 6.1 getTenantUserList（本页只用来算「已添加」）

- **Swift 签名**：
  ```swift
  func getTenantUserList(tenantId: String, keyword: String? = nil, pageNum: Int, pageSize: Int,
                         completion: @escaping (Result<([TenantUser], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.getTenantUserList`（GET）存在，但该方法自己用 `URLComponents(string: baseURL + Constants.API.getTenantUserList)` 拼 URL，手动设 `Authorization`，未走统一 `request(endpoint:)`。
- **请求**：Query `tenantId`、`pageNum = 1`、`pageSize = 1000`（本页不传 `keyword`）。
- **响应**：`BaseResponse<[TenantUser]>` + `total`。
- **UI 处理**：只取 `userId` 组成 `addedUserIds`，失败仅打印日志。

### 6.2 searchTenantUsers

- **Swift 签名**：
  ```swift
  func searchTenantUsers(tenantId: String, companyId: String, keyword: String, pageNum: Int, pageSize: Int,
                         completion: @escaping (Result<([SearchUserResult], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.searchTenantUsers`（GET，`Constants.API.searchTenantUsers = "/service/tenant/searchTenantUsers"`），走统一 `request(endpoint:parameters:)`。
- **请求**：

  | 名称 | 位置 | 类型 | 必填 | 说明 |
  |---|---|---|---|---|
  | `tenantId` | Query | String | 是 | 当前租户 ID（后端用于标记是否已在租户中） |
  | `companyId` | Query | String | 是 | 搜索范围限定为该公司 |
  | `keyword` | Query | String | 是 | 姓名或工号 |
  | `pageNum` | Query | Int | 是 | 页码 |
  | `pageSize` | Query | Int | 是 | 20 |

- **响应**：`BaseResponse<[SearchUserResult]>`，`total` 为总数。后端文档 §12 说明 data 为「用户列表（标记是否已在租户中）」，对应客户端 `SearchUserResult.checked`（0 未添加 / 1 已添加）。
- **UI 处理**：成功 → 填 `searchResults` + 更新 `hasMoreData`；失败仅 `print`。

### 6.3 addTenantUser

- **Swift 签名**：`func addTenantUser(tenantId: String, userId: String, completion: @escaping (Result<Int, NetworkError>) -> Void)`
- **APIEndpoint**：`.addTenantUser(String, String)`，`path` = `Constants.API.addTenantUser` 依次 `replacingOccurrences(of: "{tenantId}")` / `("{userId}")`，`method` 落在 POST 分支。占位符替换正确（可与 `APIEndpoint.deletePrompt` 的错误替换对照）。
- **请求**：两参数全在 Path，`parameters` 传空字典 `[:]`。
- **响应**：`BaseResponse<Int>`，客户端把 `data` 原样透出，页面按 `data > 0` 判成功。后端文档 §7 出参示例 `data` 为 `null`，与客户端「`data > 0` 才算成功」的判定口径不一致（见 10.1）。
- **UI 处理**：成功 → alert「添加成功」+ 该行变「已添加」；`data <= 0` → alert「添加失败，请稍后重试」。

## 7. 数据模型

### 7.1 SearchUserResult（`Models/SearchUserResult.swift`）

本页用到的字段：

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String?` | 是 | 用户 ID，既作 `ForEach` 的 id，也作 `addTenantUser` 的 `userId` |
| `username` | `String` | 否 | 昵称（行标题） |
| `userAccount` | `String` | 否 | 工号（行副标题） |
| `avater` | `String?` | 是 | 头像相对路径 |
| `checked` | `Int?` | 是 | 0 未添加 / 1 已添加（后端标记，**本页未使用**） |

其余字段（`createDate`、`updateDate`、`telephone`、`email`、`birthday`、`sex`、`role`、`password`、`sign`、`region`、`disabled`、`permission`）本页不展示。便捷属性 `isAdded`（`checked == 1`）本页也未使用。

### 7.2 TenantUser（`Models/TenantUser.swift`）

本页只取 `userId` 字段用于组装 `addedUserIds`，完整字段见 [TenantManagePage](TenantManagePage.md) §7。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor`，内边距 `Dimens.middleMargin`，底部 1px `Colors.grayColor` |
| 返回图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont` / `.black` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，背景 `whiteColor`，描边 `grayColor.opacity(0.5)` |
| 搜索栏容器 | 水平 `middleMargin`，垂直 `Dimens.smallIcon`，底部 1px `grayColor.opacity(0.3)` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 头像 | `Dimens.middleAvater` |
| 用户名 / 工号 | `Dimens.normalFont` `.black` / `Dimens.normalFont - 2` `Colors.grayColor` |
| 「添加」按钮 | 背景 `Colors.primaryColor`，`Colors.whiteColor` 文字，圆角 `Dimens.borderRadius * 2`，内边距 `middleMargin` / `smallMargin` |
| 「已添加」标签 | `Colors.grayColor` 文字 + `grayColor.opacity(0.2)` 背景，圆角 `Dimens.borderRadius * 2` |
| 添加中 | `ProgressView()` 尺寸 `Dimens.middleIcon` |
| 空状态图标 | `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入页面

```
TenantManagePage 点「plus」（tenantUserRole >= 1）
  → navigationDestination → AddTenantUserPage
     onAppear → loadAddedUsers()
        → GET getTenantUserList(tenantId, pageNum: 1, pageSize: 1000)
        → addedUserIds = Set(users.map { $0.userId })
     初始 searchResults 为空且 searchText 为空 → emptySearchView（引导输入）
```

### 9.2 搜索 + 分页

```
输入关键词 → onChange → handleSearchTextChange
   空串   → 清空结果 + 重置分页
   非空串 → 立即重置分页/清空列表 → 0.5s 后 performSearch(reset: true)
              guard tenantId & companyId（currentCompany?.id ?? getCachedCompanyId()）
              → GET searchTenantUsers(tenantId, companyId, keyword, pageNum: 1, pageSize: 20)
              → searchResults 填充；hasMoreData = count < total
滚到底部 ProgressView.onAppear → loadMoreUsers()
   → currentPage += 1 → performSearch(reset: false) → compactMap 去重 append
```

### 9.3 添加用户

```
点行内「添加」
  → guard tenantId & user.id，且该 userId 不在 addingUserIds 中
  → addingUserIds.insert(userId)  行内变 ProgressView
  → POST addTenantUser/{tenantId}/{userId}
       data > 0  → addingUserIds.remove + alert「添加成功」+ addedUserIds.insert → 行变「已添加」
       data <= 0 → alert「添加失败，请稍后重试」（行恢复成「添加」按钮）
       failure   → alert(error.localizedDescription)
  → 不重新搜索，列表保持原状
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 → `customNavigationBar`；搜索框 → `searchBarView`；两种空态 → `emptyStateView` / `emptySearchView`；行样式与三态按钮 → `UI/Components/UserSearchRow.swift`（**公共组件，改动会同时影响 [AddCompanyUserPage](AddCompanyUserPage.md)**）。
- **加字段**：`Models/SearchUserResult.swift`（含 `CodingKeys`）→ `searchTenantUsers` 解码 → `UserSearchRow` 展示，三处同步。
- **加接口**：`Constants.API` → `APIEndpoint`（case + `path` 占位符替换 + `method` 分支）→ `HTTPClient` 方法 → 页面调用。
- **想支持「加入时直接指定角色」**：本页无角色 UI，可参考 [AddCompanyUserPage](AddCompanyUserPage.md) 的 `addUserDialog` 做法（弹层 + Picker），但 `addTenantUser` 目前的接口签名只有 Path 上的 `tenantId`/`userId`，需要后端先扩参。

### 10.1 已知坑

1. **忽略了后端给的 `checked` 标记**：行内 `isAdded` 只判断 `addedUserIds.contains(user.id ?? "")`，没有像 [AddCompanyUserPage](AddCompanyUserPage.md) 那样叠加 `|| user.isAdded`。而 `searchTenantUsers` 后端文档明确说「data 为用户列表（标记是否已在租户中）」，`SearchUserResult.checked` / `isAdded` 白定义了。若 `loadAddedUsers` 失败（只 `print`，无提示），页面会把所有已在租户里的用户都显示成可「添加」。
2. **`loadAddedUsers` 用 `pageSize: 1000` 拉全量**：成员超过 1000 人时「已添加」判断会漏，且每次进页面都要拉一次大列表。
3. **搜索失败完全静默**：`performSearch` 的 `.failure` 只 `print`，UI 表现为「未找到相关用户」，无法区分请求失败与真的无结果。
4. **`refreshData()` 的 async 时序错位**：内部调用回调式 `performSearch`，紧接着就 `MainActor.run { isRefreshing = false }`，下拉刷新 spinner 会在数据回来前消失。
5. **加载更多失败不回滚页码**：`loadMoreUsers` 先 `currentPage += 1` 再请求，失败后页码不退回，下次触发直接跳页。
6. **`hasMoreData` 依赖 `total`**：`HTTPClient` 在 `total` 缺失时兜底 `0`，此时 `searchResults.count < 0` 为 false，会立刻判定没有更多，只显示第一页。
7. **`data > 0` 与后端出参示例不一致**：`addTenantUser` 页面按 `data > 0` 判成功，但 `docs/api/tenant.md` §7 的出参示例里 `data` 是 `null`。若后端真返回 `null`，`HTTPClient.addTenantUser` 的 `if response.isSuccess, let data = response.data` 会走进 `else` → 直接报「添加用户到租户失败」。上线前需与后端确认 `data` 语义。
8. **无租户/无公司时静默返回**：`performSearch` 的两个 `guard` 只 `print`，用户输入关键词后页面毫无反应（既不 loading 也不提示）。
9. **占位按钮实现别扭**：导航栏右侧用 `Button(action: {}) { Image("chevron.left").foregroundColor(.clear) }.disabled(true)` 占位，而 [TenantManagePage](TenantManagePage.md) 用的是 `Color.clear.frame(...)`，两页写法不统一。
10. **`navigationBarHidden(true)` 重复设置**：父页 `navigationDestination` 里已对 `AddTenantUserPage()` 调过一次，本页 `body` 末尾又调了一次。
11. **`ForEach(id: \.element.id)` 的 id 是 `String?`**：`SearchUserResult.id` 可选，若后端返回 nil，多条 nil 会共用同一个 identity 导致行错乱；同时 `isAdded` / `isAdding` 用 `user.id ?? ""` 兜底空串，nil id 的行会互相串状态。
12. **间距用了图标常量**：搜索栏 `padding(.vertical, Dimens.smallIcon)`、行内 `VStack(spacing: Dimens.smallIcon)`，按样式铁律应为 `Dimens.middleMargin`（两者数值同为 15，视觉无差异）。
13. **添加成功后不刷新列表**：只本地 `addedUserIds.insert`，与 [AddCompanyUserPage](AddCompanyUserPage.md) 成功后 `performSearch(reset: true)` 的行为不一致；若后端还做了别的联动（如自动分配角色），本页看不到。
14. **`pageSize` 用 `@State` 但从不变化**：可改为 `let`。

## 相关文档

- [TenantManagePage](TenantManagePage.md)（入口/返回目标）
- [AddCompanyUserPage](AddCompanyUserPage.md)（公司侧的同类页面，带部门/职位/角色选择）
- [UserPage](UserPage.md)（租户管理入口的上一级）
- 后端接口：`docs/api/tenant.md`
