---
name: add-company-user-page
description: 添加公司用户页（AddCompanyUserPage）。搜索用户后弹层选择角色/部门/职位并加入当前公司，含 getDepartments → getPositions 级联；需要改公司成员添加流程、部门职位联动或角色规则时读这份文档。
page: AddCompanyUserPage.swift
path: chat/chat/UI/Pages/AddCompanyUserPage.swift
apis:
  - GET /service/company/searchUsers
  - GET /service/company/getCompanyUsers
  - GET /service/company/getDepartments
  - GET /service/company/getPositions
  - POST /service/company/addUser
---

# AddCompanyUserPage（添加公司用户页）

## 1. 页面职责

`AddCompanyUserPage` 负责把用户加入**当前公司**：先按姓名/工号防抖搜索候选用户，点行内「添加」弹出自绘对话框，在对话框里选择角色（仅超级管理员可见）、部门、职位（部门→职位级联加载），确认后调 `POST /service/company/addUser` 完成添加。

页面进入时会先拉一次公司成员列表，把已在公司的 ID 缓存下来，配合后端返回的 `SearchUserResult.checked` 把行内按钮显示成「已添加」。

它是 [UserManagePage](UserManagePage.md) 的下级页面，也是本项目里唯一做「部门/职位级联选择」的页面。租户侧的同类页面是 [AddTenantUserPage](AddTenantUserPage.md)（无角色/部门/职位）。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/AddCompanyUserPage.swift`（约 790 行，含 `Department` / `Position` 模型定义与内嵌 `AddUserRow` 组件）
- **入口**：[UserManagePage](UserManagePage.md) 导航栏「plus」按钮 → `.navigationDestination(isPresented: $navigateToAddUser) { AddCompanyUserPage().navigationBarHidden(true) }`（父页在 `NavigationStack` 内）
- **出口**：仅 `dismiss()` 返回 [UserManagePage](UserManagePage.md)，无其他跳转
- **依赖组件**：`UI/Components/UserAvatar.swift`、同文件内嵌 `AddUserRow`；对话框是**页面自绘的 `.overlay`**，未使用项目通用 `CustomDialog`
- **依赖模型**：`Models/SearchUserResult.swift`、`Models/CompanyUser.swift`（`loadAddedUsers` 解码用）、**本文件内定义的 `Department` / `Position`**
- **依赖服务**：`HTTPClient.shared.searchCompanyUsers`、`getCompanyUsers`、`getDepartments`、`getPositions`、`addCompanyUser`、`AppState.shared`（`currentCompany`、`getCachedCompanyId()`）、`@Environment(\.dismiss)`

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `AppState`（`@ObservedObject`，`AppState.shared`） | — | 读 `currentCompany` / 公司缓存 / 角色 |
| `dismiss` | `DismissAction`（`@Environment(\.dismiss)`） | — | 返回上一页 |
| `searchText` | `@State String` | `""` | 搜索关键词 |
| `searchResults` | `@State [SearchUserResult]` | `[]` | 搜索结果 |
| `isSearchLoading` | `@State Bool` | `false` | 搜索请求中 |
| `searchWorkItem` | `@State DispatchWorkItem?` | `nil` | 防抖任务句柄 |
| `currentPage` | `@State Int` | `1` | 搜索分页页码 |
| `pageSize` | `@State Int` | `20` | 每页条数（全程未修改） |
| `hasMoreData` | `@State Bool` | `true` | 是否还有下一页 |
| `isLoadingMore` | `@State Bool` | `false` | 加载更多中 |
| `addedUserIds` | `@State Set<String>` | `[]` | 已在公司的 ID 集合（来自 `CompanyUser.id`，见 10.1） |
| `addingUserIds` | `@State Set<String>` | `[]` | 正在添加中的用户 ID |
| `showAddDialog` | `@State Bool` | `false` | 是否显示添加对话框 |
| `selectedUser` | `@State SearchUserResult?` | `nil` | 对话框对应的用户 |
| `selectedRole` | `@State String` | `"0"` | 角色选择（**字符串** "0" 普通 / "1" 管理员） |
| `departments` | `@State [Department]` | `[]` | 部门列表 |
| `positions` | `@State [Position]` | `[]` | 职位列表 |
| `selectedDepartmentId` | `@State String?` | `nil` | 选中的部门 ID |
| `selectedPositionId` | `@State String?` | `nil` | 选中的职位 ID |
| `isLoadingDepartments` | `@State Bool` | `false` | 部门加载中 |
| `isLoadingPositions` | `@State Bool` | `false` | 职位加载中 |
| `showAlert` | `@State Bool` | `false` | 提示弹窗（与同名方法 `showAlert(message:)` 重名，见 10.1） |
| `alertMessage` | `@State String` | `""` | 提示内容 |
| `isRefreshing` | `@State Bool` | `false` | 下拉刷新中 |

计算属性：

| 属性 | 实现 | 含义 |
|---|---|---|
| `isSuperAdmin` | `appState.currentCompany?.isSuperAdmin ?? false` | 当前用户在公司是超管（role 2） |
| `isNormalAdmin` | `appState.currentCompany?.isNormalAdmin ?? false` | 普通管理员（role 1） |
| `showRoleOption` | `isSuperAdmin` | 只有超管才显示角色单选 |
| `isFormValid` | `selectedDepartmentId != nil && selectedPositionId != nil`（随后直接 `return true`） | 必须选了部门和职位 |

## 4. 视图结构

```
body: VStack(spacing: 0)          ← 无 NavigationStack，复用父页的栈
├─ customNavigationBar            背景 whiteColor / 内边距 middleMargin / 底部 1px Colors.grayColor
│    ├─ 返回 chevron.left         middleIcon / subColor → dismiss()
│    ├─ 标题「添加用户」           middleFont / .black
│    └─ 占位 Button(chevron.left) foregroundColor(.clear) + .disabled(true)
├─ searchBarView                  高 inputHeight / 圆角 inputHeight/2 / 描边 grayColor.opacity(0.5)
│    ├─ magnifyingglass          smallIcon / grayColor
│    ├─ TextField「搜索用户（姓名或工号）」 onChange → handleSearchTextChange
│    └─ !searchText.isEmpty → xmark.circle.fill
│    外层 padding(.vertical, Dimens.smallIcon) + 底部 1px grayColor.opacity(0.3)
└─ ScrollView                     背景 pageBackgroundColor / .refreshable { await refreshData() }
   └─ VStack(spacing: middleMargin) → userListCardView
        卡片：background(whiteColor) + cornerRadius(borderRadius)
        ├─ isSearchLoading && searchResults.isEmpty     → ProgressView（vertical largeMargin）
        ├─ searchResults.isEmpty && !searchText.isEmpty → emptyStateView（未找到）
        ├─ searchResults.isEmpty                        → emptySearchView（未搜索引导）
        └─ else                                         → userListView
.background(Colors.pageBackgroundColor)
.alert("提示", isPresented: $showAlert) { Button("确定", role: .cancel) }
.overlay(addUserDialog)           ← 自绘对话框
.navigationBarHidden(true)
.onAppear { loadAddedUsers() }
```

### 4.1 userListView

```
LazyVStack(spacing: 0)
├─ ForEach(searchResults.enumerated(), id: \.element.id)
│    ├─ AddUserRow(user:isAdded:isAdding:onAdd:)
│    │    isAdded  = addedUserIds.contains(user.id ?? "") || user.isAdded   // 叠加后端 checked
│    │    isAdding = addingUserIds.contains(user.id ?? "")
│    │    onAdd    = { selectedUser = user; loadDepartmentsAndPositions(); showAddDialog = true }
│    └─ index < searchResults.count - 1 → Divider().padding(.leading, middleMargin)
└─ hasMoreData && !isLoadingMore && !isRefreshing && !searchText.isEmpty
     → ProgressView().onAppear { loadMoreUsers() }
```

### 4.2 addUserDialog（`@ViewBuilder`，挂在 `.overlay`）

仅当 `showAddDialog && selectedUser != nil` 时渲染：

```
ZStack
├─ Color.black.opacity(0.5).ignoresSafeArea()
│    .onTapGesture { showAddDialog = false; resetDialogState() }     ← 点遮罩关闭
└─ VStack(spacing: Dimens.middleMargin)
   ├─ Text("选择部门和职位")        middleFont / .black / top middleMargin
   ├─ Text("用户：\(user.username)") normalFont / grayColor
   ├─ showRoleOption →「角色」区（仅超管）
   │    ├─ Text("角色") normalFont / .black
   │    └─ HStack：两个自绘单选
   │         「普通用户」selectedRole == "0" → largecircle.fill.circle / primaryColor，否则 circle / grayColor
   │         「管理员」  selectedRole == "1" → 同上
   │       两个按钮均 .buttonStyle(PlainButtonStyle())
   ├─「部门」区
   │    ├─ isLoadingDepartments → 居中 ProgressView
   │    └─ else → Picker("选择部门", selection: $selectedDepartmentId)
   │         「请选择部门」tag(nil as String?) + ForEach(departments) { Text(departmentName).tag(id) }
   │         .pickerStyle(MenuPickerStyle()) / 高 inputHeight / 圆角 inputHeight/2 / 背景 pageBackgroundColor
   │         .onChange(of: selectedDepartmentId):
   │             有值 → loadPositions(departmentId:)
   │             nil  → positions = []; selectedPositionId = nil
   ├─「职位」区
   │    ├─ isLoadingPositions          → 居中 ProgressView
   │    ├─ selectedDepartmentId != nil → Picker("选择职位", selection: $selectedPositionId)（样式同部门）
   │    └─ else                        → Text("请先选择部门") normalFont / grayColor
   └─ 按钮区 HStack(spacing: middleMargin)
        ├─「取消」高 btnHeight / 透明底 / grayColor 描边 + grayColor 文字 → showAddDialog = false; resetDialogState()
        └─「确定」高 btnHeight / 圆角 btnHeight/2 / 白字
             背景 isFormValid ? Colors.primaryColor : Colors.grayColor，.disabled(!isFormValid)
             action: role = showRoleOption ? (Int(selectedRole) ?? 0) : 0
                     → addUserToCompany(user:role:positionId: selectedPositionId)
   .frame(width: UIScreen.main.bounds.width - Dimens.largeMargin * 4)
   .background(Colors.whiteColor).cornerRadius(Dimens.borderRadius)
```

### 4.3 两种空状态

| 视图 | 触发条件 | 内容 |
|---|---|---|
| `emptyStateView` | `searchResults.isEmpty && !searchText.isEmpty` | `person.slash`（`bigIcon`/`grayColor`）+「未找到相关用户」+「请尝试其他关键词」（`normalFont - 2`） |
| `emptySearchView` | `searchResults.isEmpty`（`searchText` 为空） | `magnifyingglass`（`bigIcon`/`grayColor`）+「输入姓名或工号搜索用户」 |

### 4.4 AddUserRow（同文件内嵌）

结构与 [AddTenantUserPage](AddTenantUserPage.md) 的 `UserSearchRow` 完全一致（头像 + 用户名/工号 + 尾部三态「已添加」/`ProgressView`/「添加」按钮），是两份平行实现的重复组件。

## 5. 核心方法

### `handleSearchTextChange(_ newValue: String)`
- **触发**：搜索框 `.onChange(of: searchText)`
- **步骤**：`searchWorkItem?.cancel()` → 空串则清空结果并重置分页后 return → 非空则先重置分页/清空列表，再 `asyncAfter(.now() + 0.5)` 执行 `performSearch(reset: true)`。

### `performSearch(reset: Bool = true)`
- **触发**：防抖任务、`loadMoreUsers()`、`refreshData()`、**添加成功后**
- **步骤**：
  1. `guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { print("❌ 未找到公司ID"); return }`。
  2. `guard !searchText.isEmpty else { return }`。
  3. `reset` → `isSearchLoading = true`、`currentPage = 1`、`searchResults = []`。
  4. 调 `searchCompanyUsers(keyword:companyId:pageNum:pageSize:)`（注意参数顺序是 `keyword` 在前）。
  5. 主线程回调：`isSearchLoading = false`、`isLoadingMore = false`；成功 → `reset` 整体替换 / 否则 `compactMap` 去重 append，`hasMoreData = searchResults.count < total`；失败 → `print` 且仅在 `reset` 时清空（**不弹 alert**）。

### `loadMoreUsers()`
- **触发**：列表底部 `ProgressView.onAppear`
- **步骤**：`guard !isLoadingMore && hasMoreData && !searchText.isEmpty` → `isLoadingMore = true` → `currentPage += 1` → `performSearch(reset: false)`。

### `refreshData() async`
- **触发**：`ScrollView.refreshable`
- **步骤**：`MainActor.run { isRefreshing = true }` → `searchText` 非空则 `performSearch(reset: true)` → `MainActor.run { isRefreshing = false }`（不等回调）。

### `loadAddedUsers()`
- **触发**：`.onAppear`
- **步骤**：`guard companyId` → `getCompanyUsers(companyId:pageNum: 1, pageSize: 1000)` → 成功 `addedUserIds = Set(users.compactMap { $0.id })`；失败仅 `print`。

### `resetDialogState()`
- **触发**：对话框「取消」、点遮罩、`addUserToCompany` 内部
- **步骤**：`selectedRole = "0"`、`selectedDepartmentId = nil`、`selectedPositionId = nil`、`departments = []`、`positions = []`（**不清 `selectedUser`**）。

### `loadDepartmentsAndPositions()`
- **触发**：行内「添加」按钮（在 `showAddDialog = true` 之前调用）
- **步骤**：
  1. `guard companyId`，否则 `print("❌ 未找到公司ID")` 并 return（此时对话框仍会被打开）。
  2. 重置 `departments` / `positions` / `selectedDepartmentId` / `selectedPositionId`。
  3. `isLoadingDepartments = true` → `getDepartments(companyId:)`。
  4. 主线程回调：`isLoadingDepartments = false`；成功 → `departments = depts` + `print`；失败 → `print` + `showAlert(message: "获取部门列表失败")`。
- **注意**：方法名与注释说「先加载部门，部门加载完成后自动加载职位」，实际**只加载部门**，职位靠 Picker 的 `onChange(of: selectedDepartmentId)` 触发。

### `loadPositions(departmentId: String)`
- **触发**：部门 Picker 的 `.onChange(of: selectedDepartmentId)`（非 nil 分支）
- **步骤**：`isLoadingPositions = true` → 清空 `positions` / `selectedPositionId` → `getPositions(departmentId:)` → 成功 `positions = posList`；失败 `print` + `showAlert(message: "获取职位列表失败")`。

### `addUserToCompany(user: SearchUserResult, role: Int, positionId: String?)`
- **触发**：对话框「确定」按钮
- **步骤**：
  1. `guard let companyId = ... , let userId = user.id else { showAlert(message: "缺少必要参数"); return }`。
  2. 角色降级：`isNormalAdmin` → `finalRole = 0`，否则 `finalRole = role`。
  3. `addingUserIds.insert(userId)`。
  4. `showAddDialog = false` + `resetDialogState()`（**先关框再请求**）。
  5. 调 `addCompanyUser(companyId:userId:role: finalRole, positionId:)`。
  6. 主线程回调先 `addingUserIds.remove(userId)`，再分支：
     - `data > 0` → `showAlert(message: "添加成功")`、`addedUserIds.insert(userId)`、**`performSearch(reset: true)` 重新搜索**。
     - `data <= 0` → 「添加失败，请稍后重试」。
     - `.failure` → `error.localizedDescription`。

### `showAlert(message: String)`
- **步骤**：`alertMessage = message`、`showAlert = true`。与 `@State private var showAlert` 同名（属性 vs 方法），可编译但极易误读。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `getCompanyUsers` | GET | `/service/company/getCompanyUsers` | `onAppear`（`pageSize: 1000`） | `docs/api/company.md` §2 |
| 2 | `searchCompanyUsers` | GET | `/service/company/searchUsers` | 防抖搜索 / 加载更多 / 下拉刷新 / 添加成功后 | `docs/api/company.md` §3 |
| 3 | `getDepartments` | GET | `/service/company/getDepartments` | 点「添加」打开对话框 | `docs/api/company.md` §7 |
| 4 | `getPositions` | GET | `/service/company/getPositions` | 部门 Picker 选中变化 | `docs/api/company.md` §8 |
| 5 | `addCompanyUser` | POST | `/service/company/addUser` | 对话框「确定」 | `docs/api/company.md` §4 |

### 6.1 getCompanyUsers（只用来算「已添加」）

- **Swift 签名**：
  ```swift
  func getCompanyUsers(companyId: String, keyword: String? = nil, pageNum: Int, pageSize: Int,
                       completion: @escaping (Result<([CompanyUser], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.getCompanyUsers`（GET）存在，但方法内部手工拼 URL、手动设 `Authorization`，未走 `request(endpoint:)`。
- **请求**：Query `companyId`、`pageNum = 1`、`pageSize = 1000`。
- **响应**：`BaseResponse<[CompanyUser]>` + `total`。
- **UI 处理**：`addedUserIds = Set(users.compactMap { $0.id })`；失败仅打印。

### 6.2 searchCompanyUsers

- **Swift 签名**：
  ```swift
  func searchCompanyUsers(keyword: String, companyId: String, pageNum: Int, pageSize: Int,
                          completion: @escaping (Result<([SearchUserResult], Int), NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.searchCompanyUsers`（GET / `Constants.API.searchCompanyUsers = "/service/company/searchUsers"`），走统一 `request(endpoint:parameters:)`。
- **请求**：Query `keyword`、`companyId`、`pageNum`、`pageSize`。
- **响应**：`BaseResponse<[SearchUserResult]>` + `total`；`checked`（0/1）标记是否已在公司。
- **UI 处理**：成功 → 填 `searchResults`、更新 `hasMoreData`；失败仅 `print`。

### 6.3 getDepartments

- **Swift 签名**：`func getDepartments(companyId: String, completion: @escaping (Result<[Department], NetworkError>) -> Void)`
- **APIEndpoint**：**没有对应 case**。方法直接用 `URLComponents(string: baseURL + Constants.API.getDepartments)` 手工拼 GET 请求并自己设 `Authorization`。
- **请求**：Query `companyId`。
- **响应**：`BaseResponse<[Department]>`。后端文档 §7 示例为 `{"id","companyId","departmentName","role"}`，客户端 `Department` 解 `id/companyId/departmentName/description/createTime`（**多解 `description`、`createTime`，不解 `role`**，均为可选或后端文档未覆盖字段）。
- **UI 处理**：成功 → `departments`；失败 → alert「获取部门列表失败」。

### 6.4 getPositions

- **Swift 签名**：`func getPositions(departmentId: String, completion: @escaping (Result<[Position], NetworkError>) -> Void)`
- **APIEndpoint**：`.getPositions`（GET / `Constants.API.getPositions = "/service/company/getPositions"`），走统一 `request(endpoint:parameters:)`。
- **请求**：Query `departmentId`。
- **响应**：`BaseResponse<[Position]>`。后端文档 §8 示例为 `{"id","departmentId","positionName"}`，客户端 `Position` 另解可选 `description` / `createTime`。
- **鉴权**：后端文档明确写「除 `getPositions` 外，其余接口均需 token」，即本接口无需鉴权，但客户端仍会带 `Authorization`（无害）。
- **UI 处理**：成功 → `positions`；失败 → alert「获取职位列表失败」。

### 6.5 addCompanyUser

- **Swift 签名**：
  ```swift
  func addCompanyUser(companyId: String, userId: String, role: Int, positionId: String?,
                      completion: @escaping (Result<Int, NetworkError>) -> Void)
  ```
- **APIEndpoint**：`.addCompanyUser`（POST / `Constants.API.addCompanyUser = "/service/company/addUser"`）。
- **请求**（Body，`request(endpoint:parameters:)` 组装）：

  | 名称 | 位置 | 类型 | 必填 | 说明 |
  |---|---|---|---|---|
  | `userId` | Body | String | 是 | 被添加用户 ID |
  | `companyId` | Body | String | 是 | 公司 ID |
  | `role` | Body | Int | 是 | 0 普通成员 / 1 管理员（普通管理员强制 0） |
  | `positionId` | Body | String | 否 | 非空才拼入 |
  | ~~`departmentId`~~ | — | — | — | **后端 `AddCompanyUserSchema` 有此字段，客户端不发送**（见 10.1） |

- **响应**：`BaseResponse<Int>`。`HTTPClient` 里 `isSuccess` 但 `data` 为 nil 时会兜底 `completion(.success(0))`，页面按 `data > 0` 判成功 → **后端若返回 `data: null`（文档 §4 示例即为 null），页面会提示「添加失败，请稍后重试」**。
- **UI 处理**：成功 → alert「添加成功」+ `addedUserIds.insert` + 重新搜索；否则 alert 失败文案。

## 7. 数据模型

### 7.1 Department（**定义在 `AddCompanyUserPage.swift` 顶部**）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 部门 ID（Picker tag、`getPositions` 入参） |
| `companyId` | `String` | 否 | 所属公司 |
| `departmentName` | `String` | 否 | 部门名（Picker 显示） |
| `description` | `String?` | 是 | 描述（未展示；后端文档未覆盖） |
| `createTime` | `String?` | 是 | 创建时间（未展示；后端文档未覆盖） |

### 7.2 Position（**同样定义在页面文件里**）

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | `String` | 否 | 职位 ID（Picker tag、`addCompanyUser` 的 `positionId`） |
| `positionName` | `String` | 否 | 职位名（Picker 显示） |
| `departmentId` | `String` | 否 | 所属部门 |
| `description` | `String?` | 是 | 描述（未展示） |
| `createTime` | `String?` | 是 | 创建时间（未展示） |

### 7.3 SearchUserResult（`Models/SearchUserResult.swift`）

本页用到：`id`（`String?`，作 identity + `userId` 入参）、`username`、`userAccount`、`avater`、`checked`（`Int?`）及便捷属性 `isAdded`（`checked == 1`，**本页确实使用了**）。

### 7.4 CompanyUser（`Models/CompanyUser.swift`）

本页只取 `id` 组装 `addedUserIds`，完整字段见 [UserManagePage](UserManagePage.md) §7。注意该模型同时有 `id` 与 `userId` 两个字段。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 / ScrollView 背景 | `Colors.pageBackgroundColor` |
| 导航栏背景 | `Colors.whiteColor`，内边距 `Dimens.middleMargin`，底部 1px `Colors.grayColor` |
| 返回图标 | `Colors.subColor`，`Dimens.middleIcon` |
| 标题 | `Dimens.middleFont` / `.black` |
| 搜索框 | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，描边 `grayColor.opacity(0.5)` |
| 搜索栏容器 | 水平 `middleMargin`，垂直 `Dimens.smallIcon`，底部 1px `grayColor.opacity(0.3)` |
| 列表卡片 | `Colors.whiteColor` + `Dimens.borderRadius` |
| 头像 | `Dimens.middleAvater` |
| 「添加」按钮 | `Colors.primaryColor` 底 + `Colors.whiteColor` 字，圆角 `Dimens.borderRadius * 2` |
| 「已添加」标签 | `Colors.grayColor` 字 + `grayColor.opacity(0.2)` 底，圆角 `Dimens.borderRadius * 2` |
| 对话框遮罩 | `Color.black.opacity(0.5)` |
| 对话框容器 | `Colors.whiteColor` + `Dimens.borderRadius`，宽 `UIScreen.main.bounds.width - Dimens.largeMargin * 4` |
| 对话框标题 / 用户名 | `Dimens.middleFont` `.black` / `Dimens.normalFont` `Colors.grayColor` |
| 角色单选 | 选中 `largecircle.fill.circle` + `Colors.primaryColor`，未选 `circle` + `Colors.grayColor` |
| Picker（部门/职位） | 高 `Dimens.inputHeight`，圆角 `inputHeight / 2`，背景 `Colors.pageBackgroundColor`，`MenuPickerStyle` |
| 「取消」按钮 | 高 `Dimens.btnHeight`，透明底 + `Colors.grayColor` 描边/文字，圆角 `btnHeight / 2` |
| 「确定」按钮 | 高 `Dimens.btnHeight`，圆角 `btnHeight / 2`，`isFormValid ? Colors.primaryColor : Colors.grayColor` 底 + 白字 |
| 空状态图标 | `Dimens.bigIcon` + `Colors.grayColor` |

## 9. 交互流程

### 9.1 进入页面

```
UserManagePage 点「plus」→ navigationDestination → AddCompanyUserPage
  onAppear → loadAddedUsers()
     companyId = currentCompany?.id ?? getCachedCompanyId()
     → GET getCompanyUsers(companyId, pageNum: 1, pageSize: 1000)
     → addedUserIds = Set(users.compactMap { $0.id })
  searchResults 为空 + searchText 为空 → emptySearchView（引导输入）
```

### 9.2 搜索 + 分页

```
输入 → onChange → handleSearchTextChange（0.5s 防抖，先重置分页）
  → performSearch(reset: true)
      guard companyId & searchText 非空
      → GET /service/company/searchUsers?keyword&companyId&pageNum=1&pageSize=20
      → searchResults 填充；hasMoreData = count < total
滚到底 ProgressView.onAppear → loadMoreUsers() → currentPage += 1 → performSearch(reset: false)
```

### 9.3 添加用户（含部门/职位级联）

```
点行内「添加」
  → selectedUser = user
  → loadDepartmentsAndPositions()
       重置 departments/positions/selectedDepartmentId/selectedPositionId
       isLoadingDepartments = true → GET getDepartments(companyId)
       成功 → departments 填充；失败 → alert「获取部门列表失败」（对话框仍打开且部门为空）
  → showAddDialog = true → overlay 渲染 addUserDialog

对话框内：
  超管 → 显示「角色」单选（默认 "0" 普通用户）；非超管 → 不显示，角色按 0 提交
  选部门（Picker） → onChange(selectedDepartmentId)
       非 nil → loadPositions(departmentId:)：清空职位 → GET getPositions(departmentId)
       nil    → positions = []、selectedPositionId = nil
  未选部门时职位区显示「请先选择部门」
  「确定」按钮：仅当 selectedDepartmentId != nil && selectedPositionId != nil 时可点（否则灰底 + disabled）
       role = showRoleOption ? (Int(selectedRole) ?? 0) : 0
       → addUserToCompany(user:role:positionId:)
            isNormalAdmin → finalRole 强制 0
            addingUserIds.insert → 立即关框 + resetDialogState()
            → POST /service/company/addUser { userId, companyId, role, positionId? }
                 data > 0  → alert「添加成功」+ addedUserIds.insert + performSearch(reset: true)
                 data <= 0 → alert「添加失败，请稍后重试」
                 failure   → alert(error.localizedDescription)
  「取消」或点遮罩 → showAddDialog = false + resetDialogState()
```

### 9.4 「已添加」状态的两个来源

```
isAdded = addedUserIds.contains(user.id ?? "")   ← onAppear 拉全量成员列表得到
        || user.isAdded                          ← 后端 searchUsers 返回的 checked == 1
两者任一为真即显示灰色「已添加」标签，行内不再有「添加」按钮
```

## 10. 二次开发指引

- **改文案/样式**：导航栏 → `customNavigationBar`；搜索框 → `searchBarView`；空态 → `emptyStateView` / `emptySearchView`；对话框（含角色单选、两个 Picker、按钮区）→ `addUserDialog`；行样式 → `AddUserRow`。
- **加字段**：`SearchUserResult`（含 `CodingKeys`）→ `searchCompanyUsers` 解码 → `AddUserRow`；部门/职位字段则改本文件顶部的 `Department` / `Position`（建议同时迁移到 `Models/`）。
- **加接口**：`Constants.API` → `APIEndpoint`（case + `path` + `method`）→ `HTTPClient` 方法 → 页面调用。注意 `getDepartments` 目前**绕过**了 `APIEndpoint`，新增同类接口时不要照抄这种手工拼 URL 的写法。
- **要把 `departmentId` 提交给后端**：在 `addCompanyUser` 签名里加 `departmentId: String?` → `parameters["departmentId"]` → 页面 `addUserToCompany` 传 `selectedDepartmentId`（对话框已有这个值）。

### 10.1 已知坑

1. **`departmentId` 选了但没提交**：对话框强制要求选部门（`isFormValid` 里 `selectedDepartmentId != nil`），但 `addCompanyUser` 的请求体只有 `userId` / `companyId` / `role` / `positionId`。后端 `AddCompanyUserSchema`（`docs/api/company.md` §「请求体实体字段」）明确包含 `departmentId`。当前部门只用于级联出职位，**并未随请求落库**，只能靠后端从 `positionId` 反查部门。
2. **`addedUserIds` 用的可能是错误的 ID**：`loadAddedUsers` 取 `CompanyUser.id`（`compactMap { $0.id }`），而比对对象是 `SearchUserResult.id`（用户 ID）。`CompanyUser` 同时有 `id` 与 `userId` 两个字段，若后端 `getCompanyUsers` 返回的 `id` 是 `company_user` 关联记录 ID 而非用户 ID，则「已添加」判断完全失效。对比 [AddTenantUserPage](AddTenantUserPage.md) 的 `loadAddedUsers` 取的是 `$0.userId`。当前之所以看起来能用，是因为叠加了 `|| user.isAdded`（后端 `checked`）兜底。
3. **`@State showAlert` 与 `func showAlert(message:)` 同名**：属性和方法同名可编译（签名不同），但 `showAlert = true` 与 `showAlert(message:)` 出现在同一文件里极易误读，建议方法改名 `presentAlert(_:)`。
4. **`isFormValid` 注释与实现不符**：注释写「如果是超级管理员，还需要选择角色（默认已选0）」，实现是 `guard` 完部门职位后直接 `return true`，`selectedRole` 从未参与校验。
5. **`getDepartments` 没有 `APIEndpoint` case**：直接用 `Constants.API.getDepartments` 手工拼 URL，method/鉴权/解码各写一遍，与项目「所有接口经 `APIEndpoint` 声明」的约定不符（`getTenantUserList`、`getCompanyUsers` 有 case 但同样绕过了 `request()`）。
6. **`Department` / `Position` 模型定义在页面文件里**：不在 `Models/` 目录，其他页面若要复用只能连页面文件一起编译，且与后端文档的字段对不齐（多解 `description`/`createTime`、不解 `role`）。
7. **角色权限只在客户端限制**：`isNormalAdmin` 时强制 `finalRole = 0`，`showRoleOption` 为 false 时按钮传 `role = 0`；若既非超管也非普通管理员（普通成员）仍能进本页，则会以 `role = 0` 提交。真正的权限校验依赖后端。
8. **`selectedRole` 用 `String` 存角色**：`"0"` / `"1"` 再 `Int(selectedRole) ?? 0` 转回来，多了一层无意义转换，容易与 `CompanyUser.role: Int?` 混淆。
9. **部门加载失败时对话框仍打开**：`onAdd` 里先 `loadDepartmentsAndPositions()` 再 `showAddDialog = true`；接口失败只弹「获取部门列表失败」，对话框照样显示且部门 Picker 为空，用户只能取消。
10. **职位加载依赖 Picker 的 `onChange`**：`loadPositions` 只由部门 `Picker.onChange(of: selectedDepartmentId)` 触发，而该 Picker 在 `isLoadingDepartments == true` 时不存在于视图树。若后续把默认部门改成代码预选，`onChange` 可能不触发，职位列表会一直为空。方法名 `loadDepartmentsAndPositions` 也名不副实（只加载部门）。
11. **先关框再请求导致 `isAdding` 几乎不可见**：`addUserToCompany` 里 `addingUserIds.insert` 之后立刻 `showAddDialog = false`，行内 `ProgressView` 只在关框后的极短时间内显示。
12. **`data > 0` 与后端出参示例不一致**：`docs/api/company.md` §4 出参示例 `data` 为 `null`，`HTTPClient.addCompanyUser` 在 `data == nil` 时兜底 `success(0)`，页面按 `data > 0` 判定 → 会误报「添加失败，请稍后重试」，尽管后端其实成功了。上线前必须与后端对齐 `data` 语义。
13. **添加成功后 `performSearch(reset: true)` 会重置列表**：滚动位置与分页状态全部丢失，用户需要重新滑到原位置继续添加。
14. **对话框宽度写死**：`UIScreen.main.bounds.width - Dimens.largeMargin * 4`（即左右各留 40）用的是全屏宽度，iPad 分屏 / 多窗口场景下不自适应；且未复用项目通用 `CustomDialog` 组件，样式演进要改两处。
15. **Picker 样式不完全符合输入框规范**：背景用 `Colors.pageBackgroundColor`、无描边，而样式铁律里输入框是 `whiteColor` + `grayColor.opacity(0.5)` 描边。
16. **搜索失败静默 / `refreshData` async 时序错位 / 加载更多失败不回滚页码 / `hasMoreData` 依赖 `total` 兜底 0 / `ForEach(id: \.element.id)` 的 id 为 `String?`**：这五点与 [AddTenantUserPage](AddTenantUserPage.md) 完全同源，详见该文档 §10.1 第 3～6、11 条。
17. **`AddUserRow` 与 `UserSearchRow` 是两份重复实现**：本页 `AddUserRow` 与 `AddTenantUserPage` 的 `UserSearchRow` 结构、样式、三态逻辑一致，仅 `isAdded` 计算方式不同，可抽成公共组件放进 `UI/Components/`。
18. **`pageSize` 用 `@State` 但从不变化**；`loadAddedUsers` 的 `pageSize: 1000` 是隐式上限，成员超 1000 会漏判「已添加」。

## 相关文档

- [UserManagePage](UserManagePage.md)（入口/返回目标）
- [AddTenantUserPage](AddTenantUserPage.md)（租户侧同类页面，无角色/部门/职位）
- [UserPage](UserPage.md)（用户管理入口的上一级）
- 后端接口：`docs/api/company.md`
