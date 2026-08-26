---
name: tenant-manage-page
description: 租户管理页（TenantManagePage）。管理当前租户的成员：分页列表 + 防抖搜索 + 左滑「设为/取消管理员」「删除」；需要改租户成员权限规则、滑动交互或成员列表分页时读这份文档。
page: TenantManagePage.swift
path: chat/chat/UI/Pages/TenantManagePage.swift
apis:
  - GET /service/tenant/getTenantUserList
  - PUT /service/tenant/addAdmin/{tenantId}/{userId}
  - PUT /service/tenant/cancelAdmin/{tenantId}/{userId}
---

# TenantManagePage（租户管理页）

## 1. 页面职责

`TenantManagePage` 用来管理**当前租户**（`AppState.shared.currentTenant`）下的成员：分页展示租户成员列表、按关键词搜索成员、通过左滑手势对成员「设为管理员 / 取消管理员」或「删除」，并提供入口跳转到 [AddTenantUserPage](AddTenantUserPage.md) 把新用户加入租户。

它面向租户管理员（`role == 1`）和超级管理员（`role == 2`）：入口按钮在 [UserPage](UserPage.md) 中由 `tenantUserRole > 0` 控制显示，页面内的「+ 添加」按钮由 `tenantUserRole >= 1` 控制。

注意本页管理的是**租户维度**的成员（`TenantUser`）。公司维度的成员管理是另一条线，见 [UserManagePage](UserManagePage.md)。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/TenantManagePage.swift`（约 763 行，含内嵌 `SwipeableTenantUserRow` 组件）
- **入口**：[UserPage](UserPage.md) 的「租户管理」按钮 → `.fullScreenCover(isPresented: $navigateToTenantManagePage) { TenantManagePage() }`（`UserPage` 里条件为 `tenantUserRole > 0`）
- **出口**：
  - `AddTenantUserPage()` —— `.navigationDestination(isPresented: $navigateToAddUser)`，目标页加 `.navigationBarHidden(true)`
  - `dismiss()` —— 返回 `UserPage`
- **依赖组件**：`UI/Components/UserAvatar.swift`（`UserAvatar(avatarUrl:username:size:)`）、同文件内嵌 `SwipeableTenantUserRow`
- **依赖模型**：`Models/TenantUser.swift`
- **依赖服务**：`HTTPClient.shared.getTenantUserList`、`HTTPClient.shared.addAdmin`、`HTTPClient.shared.cancelAdmin`、`AppState.shared`、`@Environment(\.dismiss)`
- **额外依赖**：`UIKit`（`UIAlertController` / `UIApplication.shared.connectedScenes`，用于删除确认弹窗）

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentTenant`、`userData` |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 关闭页面 |
| `tenantUsers` | `@State [TenantUser]` | `[]` | 租户成员主列表 |
| `isLoading` | `@State Bool` | `false` | 首屏/重置加载态 |
| `isLoadingMore` | `@State Bool` | `false` | 加载更多中 |
| `currentPage` | `@State Int` | `1` | 当前页码 |
| `hasMoreData` | `@State Bool` | `true` | 是否还有下一页 |
| `pageSize` | `@State Int` | `20` | 每页条数（全程未被修改） |
| `searchText` | `@State String` | `""` | 搜索框文本 |
| `isSearching` | `@State Bool` | `false` | 是否处于搜索模式 |
| `searchResults` | `@State [TenantUser]` | `[]` | 搜索结果列表 |
| `isSearchLoading` | `@State Bool` | `false` | 搜索请求中 |
| `searchWorkItem` | `@State DispatchWorkItem?` | `nil` | 防抖任务句柄 |
| `showAlert` | `@State Bool` | `false` | 统一提示弹窗 |
| `alertMessage` | `@State String` | `""` | 提示内容 |
| `navigateToAddUser` | `@State Bool` | `false` | 是否跳 `AddTenantUserPage` |
| `isRefreshing` | `@State Bool` | `false` | 下拉刷新中 |
| `activeSwipeUserId` | `@State String?` | `nil` | 当前左滑展开的行 ID（用于互斥关闭） |

计算属性：

- `tenantUserRole: Int` = `appState.currentTenant?.role ?? 0` —— 当前登录用户在**当前租户**中的角色。

`SwipeableTenantUserRow` 自身状态：`offset: CGFloat = 0`（滑动偏移）、`dragStartLocation: CGFloat = 0`、`appState`（`@ObservedObject`）。

## 4. 视图结构

```
body: NavigationStack
└─ VStack(spacing: 0)
   ├─ customNavigationBar        背景 whiteColor / 上下左右 middleMargin / 底部 1px Colors.grayColor
   │    ├─ 返回 chevron.left     middleIcon / subColor → dismiss()
   │    ├─ 标题「租户管理」       middleFont / .black
   │    └─ tenantUserRole >= 1 ? 「plus」按钮(middleIcon/subColor) : Color.clear 占位(middleIcon×middleIcon)
   ├─ searchBarView              胶囊输入框：高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
   │    ├─ magnifyingglass       smallIcon / grayColor
   │    ├─ TextField「搜索用户」  onChange → handleSearchTextChange
   │    └─ !searchText.isEmpty → xmark.circle.fill 清空按钮
   │    外层 padding(.vertical, Dimens.smallIcon) + 底部 1px grayColor.opacity(0.3)
   └─ ScrollView                 背景 pageBackgroundColor / .refreshable { await refreshData() }
      └─ VStack(spacing: middleMargin) → userListCardView
           卡片：background(whiteColor) + cornerRadius(borderRadius)
           ├─ isLoading                                → ProgressView（vertical largeMargin）
           ├─ (isSearching ? searchResults : tenantUsers).isEmpty → emptyStateView
           └─ else                                     → userListView
.background(Colors.pageBackgroundColor)
.alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
.onAppear { loadTenantUserList() }
.navigationDestination(isPresented: $navigateToAddUser) { AddTenantUserPage().navigationBarHidden(true) }
```

### 4.1 userListView

```
LazyVStack(spacing: 0)
├─ ForEach(users.enumerated(), id: \.element.id)
│    ├─ SwipeableTenantUserRow(tenantUser:currentUserRole:isActiveSwipe:onSwipeStateChanged:onDelete:onRoleChange:)
│    └─ index < users.count - 1 → Divider().padding(.leading, middleMargin)
├─ !isSearching && hasMoreData && !isLoadingMore && !isRefreshing
│    → ProgressView().onAppear { loadMoreTenantUsers() }      // 触底加载更多
└─ isSearching && isSearchLoading → ProgressView()            // 搜索纯 loading，不做分页
```

`let users = isSearching ? searchResults : tenantUsers`。

### 4.2 emptyStateView

`person.slash`（`bigIcon` / `grayColor`）+ 文案 `isSearching ? "未找到相关用户" : "暂无用户"`（`normalFont` / `grayColor`），垂直 `largeMargin`。

### 4.3 SwipeableTenantUserRow（同文件内嵌）

```
GeometryReader → ZStack
├─ 背景层 HStack(spacing: 0)  Spacer + 操作按钮
│    ├─ showAdminButton  → Button(adminButtonText) 宽 100 / 背景 Colors.primaryColor / 白字
│    └─ showDeleteButton → Button("删除")           宽 70  / 背景 Colors.warnColor / 白字
└─ 前景层 HStack(spacing: middleMargin)  .background(whiteColor).offset(x: offset)
     ├─ UserAvatar(avatarUrl: tenantUser.avater, username:, size: middleAvater)
     ├─ VStack(alignment: .leading, spacing: Dimens.smallIcon)
     │    ├─ Text(username)     normalFont / .black
     │    └─ Text(userAccount)  normalFont-2 / grayColor
     ├─ Spacer
     └─ tenantUser.shouldShowRoleTag → Text(roleText)
          normalFont-4 / primaryColor / 背景 primaryColor.opacity(0.1) / 圆角 smallIcon
     .highPriorityGesture(DragGesture) + .onTapGesture 复位
行高固定 Dimens.middleAvater + Dimens.middleMargin * 2，外层 .clipped()
.onChange(of: isActiveSwipe) { 非 active 且已展开 → resetOffset() }
```

权限计算属性（全部读 `currentUserRole` 与 `tenantUser.role`）：

| 属性 | 规则 |
|---|---|
| `isSuperAdmin` | `currentUserRole == 2` |
| `isNormalAdmin` | `currentUserRole == 1` |
| `isNormalUser` | `currentUserRole == 0` |
| `targetIsSuperAdmin` / `targetIsAdmin` / `targetIsNormalUser` | `tenantUser.role` == 2 / 1 / 0 |
| `showAdminButton` | 必须 `isSuperAdmin`，且 `!targetIsSuperAdmin` |
| `adminButtonText` | `targetIsAdmin ? "取消管理员" : "设为管理员"` |
| `showDeleteButton` | 目标是超管 → false；超管 → `tenantUser.userId != appState.userData?.id`；普通管理员 → `targetIsNormalUser && tenantUser.userId != appState.userData?.id`；其他 → false |
| `actionButtonsWidth` | `showAdminButton` 加 100 + `showDeleteButton` 加 70 |

滑动手势：仅允许左滑（`newOffset < 0`），最大偏移 `-actionButtonsWidth`；右滑时若已展开则回收；松手阈值 `actionButtonsWidth / 2`，超过则 `withAnimation(.spring(response: 0.3, dampingFraction: 0.8))` 展开并回调 `onSwipeStateChanged(id, true)`，否则 `resetOffset()`。

## 5. 核心方法

### `handleSearchTextChange(_ newValue: String)`
- **触发**：搜索框 `.onChange(of: searchText)`
- **步骤**：
  1. `searchWorkItem?.cancel()` 取消上一个防抖任务。
  2. 文本为空 → `isSearching = false`、`searchResults = []`，直接 return（回到主列表）。
  3. 新建 `DispatchWorkItem { performSearch(keyword: newValue) }`，`DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)` 执行（0.5s 防抖）。

### `performSearch(keyword: String)`
- **触发**：防抖任务、`refreshData()` 中搜索态刷新
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id else { return }`（无租户则静默返回）。
  2. `isSearching = true`、`isSearchLoading = true`。
  3. 调 `getTenantUserList(tenantId:keyword:pageNum: 1, pageSize: 100)`（**复用列表接口**，非 `searchTenantUsers`）。
  4. 主线程回调：`isSearchLoading = false`；成功 → `searchResults = users`；失败 → `print` 并把 `searchResults` 清空（**不弹 alert**）。

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：
  1. `MainActor.run { isRefreshing = true; activeSwipeUserId = nil }`。
  2. `currentPage = 1`、`hasMoreData = true`。
  3. `isSearching` → `performSearch(keyword: searchText)`；否则 `loadTenantUserList(reset: true)`。
  4. `MainActor.run { isRefreshing = false }`。
- **注意**：第 3 步是回调式异步，第 4 步不会等它完成（见 10.1）。

### `loadTenantUserList(reset: Bool = true)`
- **触发**：`onAppear`（默认 `reset = true`）、`refreshData()`、`loadMoreTenantUsers()`（`reset = false`）
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id else { print("❌ 未找到租户ID"); return }`。
  2. `reset` → `isLoading = true`、`currentPage = 1`、`tenantUsers = []`、`hasMoreData = true`、`activeSwipeUserId = nil`。
  3. `getTenantUserList(tenantId:pageNum: currentPage, pageSize: pageSize)`。
  4. 主线程回调：`isLoading = false`、`isLoadingMore = false`。
     - 成功：`reset` → 整体替换；否则用 `Set(tenantUsers.map { $0.id })` 去重后 `append`；`hasMoreData = tenantUsers.count < total`。
     - 失败：`alertMessage = error.localizedDescription`、`showAlert = true`。

### `loadMoreTenantUsers()`
- **触发**：列表底部 `ProgressView.onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData && !isSearching` → `isLoadingMore = true` → `currentPage += 1` → `loadTenantUserList(reset: false)`。

### `deleteTenantUser(_ user: TenantUser)`
- **触发**：行内「删除」按钮回调 `onDelete`
- **步骤**：
  1. 构造 **UIKit** `UIAlertController(title: "确认删除", message: "确定要将用户 \"\(user.username)\" 从租户中移除吗？", preferredStyle: .alert)`。
  2. 加「取消」(`.cancel`) 与「确定」(`.destructive` → `performDeleteUser(user)`)。
  3. 取 `UIApplication.shared.connectedScenes.first as? UIWindowScene` 的 `windows.first?.rootViewController` 并 `present`。

### `performDeleteUser(_ user: TenantUser)`
- **步骤**：
  1. `isSearching` → 同时从 `searchResults` 和 `tenantUsers` 移除；否则只从 `tenantUsers` 移除。
  2. `alertMessage = "用户已移除"`、`showAlert = true`。
- **注意**：**完全没有网络请求**，只是本地删（见 10.1）。

### `toggleAdminStatus(_ user: TenantUser)`
- **触发**：行内管理员按钮回调 `onRoleChange`
- **步骤**：
  1. `guard let tenantId = appState.currentTenant?.id else { return }`。
  2. `let isAdmin = user.role == 1`。
  3. `isAdmin` → `cancelAdmin(tenantId:userId: user.userId)`；成功且 `success == true` → 提示「已取消管理员权限」+ `refreshLocalUserRole(user, newRoleType: 0)`；`success == false` → 「操作失败」。
  4. 否则 → `addAdmin(tenantId:userId:)`；成功 → 「已设为管理员」+ `refreshLocalUserRole(user, newRoleType: 1)`。
  5. 失败分支统一 `alertMessage = error.localizedDescription`、`showAlert = true`。

### `refreshLocalUserRole(_ user: TenantUser, newRoleType: Int)`
- **步骤**：在 `tenantUsers` 与 `searchResults` 中按 `id` 找到目标，**手工重建**一个 `TenantUser`（逐字段拷贝 `id/tenantId/tenantName/userId/userAccount/joinDate/createBy/username/avater/disabled/email`，只把 `role` 换成 `newRoleType`）后回写。
- **注意**：不重新拉接口，纯本地乐观更新。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getTenantUserList` | GET | `/service/tenant/getTenantUserList` | `onAppear` / 加载更多 / 下拉刷新 / 搜索 | `docs/api/tenant.md` §3 |
| 2 | `addAdmin` | PUT（客户端） | `/service/tenant/addAdmin/{tenantId}/{userId}` | 左滑「设为管理员」 | `docs/api/tenant.md` §9 |
| 3 | `cancelAdmin` | PUT | `/service/tenant/cancelAdmin/{tenantId}/{userId}` | 左滑「取消管理员」 | `docs/api/tenant.md` §10 |

### 6.1 getTenantUserList

- **Swift 签名**：
  ```swift
  func getTenantUserList(tenantId: String, keyword: String? = nil, pageNum: Int, pageSize: Int,
                         completion: @escaping (Result<([TenantUser], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.getTenantUserList` 存在（GET / `Constants.API.getTenantUserList`），但该方法**没走** `request(endpoint:)`，而是自己用 `URLComponents(string: baseURL + Constants.API.getTenantUserList)` 拼 URL、手动设 `Content-Type` 与 `Authorization`。
- **请求**：

  | 名称 | 位置 | 类型 | 必填 | 说明 |
  |---|---|---|---|---|
  | `tenantId` | Query | String | 是 | 租户 ID |
  | `pageNum` | Query | Int | 是 | 页码 |
  | `pageSize` | Query | Int | 是 | 每页条数（列表 20 / 搜索 100） |
  | `keyword` | Query | String | 否 | 非空才拼入 |

- **响应**：`BaseResponse<[TenantUser]>`，`total` 为总数（缺失时按 `0` 处理）。后端文档 §3 出参示例给的是 user 表字段（`userAccount/username/telephone/...`），与客户端 `TenantUser` 的解码结构（含 `tenantId/role/joinDate/disabled` 等）不完全一致，**按客户端解码结构为准**。
- **UI 处理**：成功 → 填 `tenantUsers` 或 `searchResults`、更新 `hasMoreData`；列表失败 → alert；搜索失败 → 仅 `print`。

### 6.2 addAdmin

- **Swift 签名**：`func addAdmin(tenantId: String, userId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void)`
- **APIEndpoint**：`.addAdmin(String, String)`，path 由 `Constants.API.addAdmin` 替换 `{tenantId}` / `{userId}`；`method` 落在 `.updateUser, .updatePassword, .updatePrompt, .addAdmin, .cancelAdmin, .updateModel` 分支 → **PUT**。
- **请求**：无 body / query，两个参数都在 Path。
- **响应**：`BaseResponse<Int>`，`data > 0` 映射为 `success == true`。
- **UI 处理**：成功 → alert「已设为管理员」+ 本地把该行 `role` 改成 1；`data <= 0` → 「操作失败」；网络失败 → `error.localizedDescription`。

### 6.3 cancelAdmin

- **Swift 签名**：`func cancelAdmin(tenantId: String, userId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void)`
- **APIEndpoint**：`.cancelAdmin(String, String)`（PUT，占位符替换同上）
- **请求**：Path `tenantId`、`userId`。
- **响应**：`BaseResponse<Int>`，`data > 0` → `true`。
- **UI 处理**：成功 → alert「已取消管理员权限」+ 本地把该行 `role` 改成 0。

## 7. 数据模型

### 7.1 TenantUser（`Models/TenantUser.swift`）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 关联记录 ID（列表 `ForEach` 的 id） |
| `tenantId` | `String` | 否 | 租户 ID |
| `tenantName` | `String?` | 是 | 租户名（后端可能返回 null） |
| `userId` | `String` | 否 | 用户 ID（`addAdmin` / `cancelAdmin` / 自我判断都用它） |
| `userAccount` | `String` | 否 | 工号/账号（行副标题） |
| `role` | `Int` | 否 | 0 普通 / 1 租户管理员 / 2 超级管理员 |
| `joinDate` | `String?` | 是 | 加入时间（本页未展示） |
| `createBy` | `String?` | 是 | 创建人（本页未展示） |
| `username` | `String` | 否 | 昵称（行标题、删除确认文案） |
| `avater` | `String?` | 是 | 头像相对路径，`UserAvatar` 拼 `Constants.baseURL` |
| `disabled` | `Int` | 否 | 禁用标记（本页未展示） |
| `email` | `String` | 否 | 邮箱（本页未展示） |

便捷属性：`roleText`（1→「管理员」/ 2→「超级管理员」/ 其他→`""`）、`shouldShowRoleTag`（`role > 0`）、`displayTenantName`（`tenantName ?? ""`）。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor`，内边距 `Dimens.middleMargin`，底部 1px `Colors.grayColor`（未加 opacity） |
| 返回 / 添加图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont` / `.black` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，背景 `whiteColor`，描边 `grayColor.opacity(0.5)`；搜索/清空图标 `Dimens.smallIcon` + `grayColor` |
| 搜索栏容器 | 水平 `middleMargin`，垂直 `Dimens.smallIcon`，底部 1px `grayColor.opacity(0.3)` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 行高 | `Dimens.middleAvater + Dimens.middleMargin * 2` |
| 头像 | `Dimens.middleAvater` |
| 用户名 / 账号 | `Dimens.normalFont` `.black` / `Dimens.normalFont - 2` `Colors.grayColor` |
| 角色标签 | `Dimens.normalFont - 4`，`Colors.primaryColor`，背景 `primaryColor.opacity(0.1)`，圆角 `Dimens.smallIcon` |
| 管理员操作按钮 | 宽 100，背景 `Colors.primaryColor`，白字 `normalFont` |
| 删除按钮 | 宽 70，背景 `Colors.warnColor`，白字 `normalFont` |
| 分隔线 | `Divider().padding(.leading, Dimens.middleMargin)` |
| 空状态 | `person.slash` `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入页面 → 分页列表

```
UserPage（tenantUserRole > 0 显示「租户管理」）
  → fullScreenCover → TenantManagePage
     onAppear → loadTenantUserList(reset: true)
        guard currentTenant?.id 存在（否则只 print，页面停在空态）
        → GET getTenantUserList(tenantId, pageNum: 1, pageSize: 20)
        → tenantUsers 填充；hasMoreData = count < total
     列表底部 ProgressView.onAppear → loadMoreTenantUsers()
        → currentPage += 1 → loadTenantUserList(reset: false)（Set 去重 append）
```

### 9.2 搜索（0.5s 防抖）

```
输入 → onChange → handleSearchTextChange
  空串   → isSearching = false，searchResults 清空，回到主列表
  非空串 → 取消旧 WorkItem，0.5s 后 performSearch(keyword:)
             → GET getTenantUserList(keyword, pageNum: 1, pageSize: 100)
             → isSearching = true，searchResults = users（无分页、失败不提示）
```

### 9.3 角色变更（左滑）

```
左滑行（仅超管且目标非超管时才有「设为/取消管理员」按钮）
  → 展开 actionButtonsWidth，activeSwipeUserId = 该行 id（其他行 onChange 自动收起）
  → 点按钮：先 resetOffset() 收起，再 onRoleChange() → toggleAdminStatus(user)
        role == 1 → PUT cancelAdmin → 成功 → refreshLocalUserRole(user, 0) + alert
        role != 1 → PUT addAdmin    → 成功 → refreshLocalUserRole(user, 1) + alert
  → 本地重建 TenantUser 回写，不重新请求列表
```

### 9.4 删除（左滑）

```
showDeleteButton 规则：
  目标是超管 → 永不显示
  当前是超管 → 除自己以外都显示
  当前是普通管理员 → 仅目标为普通用户且非自己
  当前是普通用户 → 不显示
点「删除」→ UIKit UIAlertController 二次确认
  → 「确定」→ performDeleteUser：仅本地 removeAll + alert「用户已移除」（无接口调用）
  → 下拉刷新后该用户会重新出现
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 → `customNavigationBar`；搜索框 → `searchBarView`；空态 → `emptyStateView`；行内容与滑动按钮 → `SwipeableTenantUserRow.body`。
- **改权限规则**：只改 `SwipeableTenantUserRow` 的 `showAdminButton` / `showDeleteButton` / `actionButtonsWidth` 三个计算属性；页面级「+」按钮的显示条件在 `customNavigationBar` 里的 `tenantUserRole >= 1`；入口按钮条件在 `UserPage` 的 `tenantUserRole > 0`。
- **加字段**：`Models/TenantUser.swift`（含 `CodingKeys`）→ `getTenantUserList` 解码 → `SwipeableTenantUserRow` 展示 → **`refreshLocalUserRole` 里两处手工重建 `TenantUser` 的构造调用也必须加**，否则编译报错。
- **加接口**（例如补上真正的删除）：`Constants.API`（新增 `deleteTenantUser = "/service/tenant/deleteTenantUser/{tenantId}/{userId}"`）→ `APIEndpoint` 加 case + `path` 占位符替换 + `method` 归到 DELETE → `HTTPClient` 新增方法 → `performDeleteUser` 内改为先请求后移除。

### 10.1 已知坑

1. **删除功能只是本地假删**：`performDeleteUser` 只做 `tenantUsers.removeAll` / `searchResults.removeAll` 并弹「用户已移除」，**没有任何网络请求**。后端已提供 `DELETE /service/tenant/deleteTenantUser/{tenantId}/{userId}`（`docs/api/tenant.md` §11），但 `Constants.API`、`APIEndpoint`、`HTTPClient` 里都没有对应定义。下拉刷新或重进页面后被「删除」的成员会原样回来。
2. **`addAdmin` 的 method 与后端文档不一致**：`APIEndpoint.method` 把 `.addAdmin` 归进 PUT 分支，而 `docs/api/tenant.md` §9 明确写 `POST /service/tenant/addAdmin/{tenantId}/{userId}`，并在总览下方注明「`addAdmin` 由 PUT 改为 POST」。客户端未跟着改，属于真实不一致，改动前需与后端确认。
3. **搜索没有走 `searchTenantUsers`**：本页搜索复用 `getTenantUserList(keyword:)`，`pageSize` 写死 `100` 且**不支持加载更多**（`isSearching` 时只渲染一个 `isSearchLoading` 的 `ProgressView`），成员超过 100 人时搜索结果会被截断。`searchTenantUsers` 只在 [AddTenantUserPage](AddTenantUserPage.md) 使用。
4. **搜索失败静默**：`performSearch` 的 `.failure` 分支只 `print` 并清空结果，用户看到的是「未找到相关用户」，无法区分「真的没有」和「请求失败」。
5. **`refreshData()` 的 async 时序错位**：方法体里第 3 步调用的是回调式网络方法，紧接着第 4 步就 `MainActor.run { isRefreshing = false }`，因此下拉刷新的系统 spinner 会在数据回来之前消失；同时 `currentPage` / `hasMoreData` 是在非 MainActor 上下文直接改写 `@State`。
6. **删除确认弹窗混用 UIKit**：`deleteTenantUser` 用 `UIAlertController` 挂到 `UIApplication.shared.connectedScenes.first` 的 `windows.first?.rootViewController` 上。本页自身是 `fullScreenCover` 呈现的，`connectedScenes.first` 不保证是当前活跃 scene，取不到时会**静默什么都不发生**；且与页面里的 SwiftUI `.alert` 两套弹窗风格并存。
7. **`hasMoreData` 依赖 `total`**：`HTTPClient` 在 `total` 缺失时兜底为 `0`，此时 `tenantUsers.count < 0` 为 false → 直接判定没有更多数据，只会显示第一页。
8. **加载更多失败不回滚页码**：`loadMoreTenantUsers` 先 `currentPage += 1` 再请求，请求失败后 `currentPage` 不会退回，下次触发会跳页漏数据。
9. **`[self]` capture list 无意义**：`loadTenantUserList` 里写了 `{ [self] result in ... }`，但 `TenantManagePage` 是 struct（值类型），该捕获列表不产生任何效果，仅造成误导。
10. **权限判定强依赖 `currentTenant`**：`tenantUserRole = appState.currentTenant?.role ?? 0`，若 `currentTenant` 为 nil，「+」按钮消失、所有左滑按钮都不显示、`loadTenantUserList` 直接 return，页面表现为「空列表且无任何操作」而无任何提示。
11. **样式细节与同批页面不一致**：本页导航栏底部分隔线用 `Colors.grayColor`（不透明），[UserManagePage](UserManagePage.md) 用的是 `grayColor.opacity(0.3)`；搜索栏垂直内边距和行内 `VStack` 的 `spacing` 用的是 `Dimens.smallIcon`（15）而非样式铁律要求的 `Dimens.middleMargin`（同为 15，视觉一致但语义错位）。
12. **`activeSwipeUserId` 互斥逻辑冗余**：`onSwipeStateChanged` 中先把 `activeSwipeUserId` 置 `nil` 再赋新值，两次写入同一帧内触发两次 `onChange`，属于可简化的写法。
13. **`pageSize` 用 `@State` 但从不变化**：可直接改成 `let` 常量。

## 相关文档

- [UserPage](UserPage.md)（入口）
- [AddTenantUserPage](AddTenantUserPage.md)（出口：把用户加入租户）
- [UserManagePage](UserManagePage.md)（公司成员管理，另一条线）
- 后端接口：`docs/api/tenant.md`
