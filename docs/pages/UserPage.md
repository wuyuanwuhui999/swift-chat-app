---
name: user-page
description: 用户中心/我的页 —— 展示并原地编辑当前用户资料（昵称/电话/邮箱/性别/生日/地区/签名）、上传头像、切换公司、退出登录，是二级页枢纽。改动该页前先读本文档。
page: UserPage.swift
path: chat/chat/UI/Pages/UserPage.swift
apis:
  - PUT /service/user/updateUser
  - POST /service/user/updateAvater
---

# UserPage（用户中心 / 我的页）

## 1. 页面职责

`UserPage` 是聊天主链路中的「用户中心 / 我的页」，由 `HomePage` 顶部头像点击进入。它承担三类职责：

1. **资料展示与原地编辑**：以卡片形式展示当前登录用户的头像、昵称、电话、邮箱、性别、出生日期、地区、个性签名，每一项都通过弹窗（`CustomDialog` / `CustomSelectionDialog` / `CustomDatePickerDialog`）原地编辑，编辑后调用 `updateUser` 持久化。
2. **头像上传**：通过 `PhotosPicker` 选图后调用 `updateAvatar`（multipart/form-data）上传并回写本地头像 URL。
3. **二级页枢纽**：提供「修改密码」「切换公司」「用户管理」「租户管理」「退出登录」等出口，是多个管理页面的入口。

> ⚠️ 注意：本页**不直接跳转** `UserInfoPage` / `AddCompanyUserPage`。这两个页面是 `UserManagePage`（用户管理）的出口，见 [UserManagePage](UserManagePage.md)。本页的「用户管理」按钮只会进入 `UserManagePage`。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/UserPage.swift`（847 行）
- **入口**：`HomePage` 中 `ChatHeader` 的 `onAvatarTap` 触发 `showUserPage = true`，以 `.fullScreenCover` 弹出，且外层包了 `NavigationView`：

  ```swift
  .fullScreenCover(isPresented: $showUserPage) {
      NavigationView {
          UserPage()
      }
  }
  ```

- **出口**（本页 `.fullScreenCover`，共 4 个）：
  - `ChangePasswordPage`（修改密码，`showChangePasswordPage`）
  - `CompanyPage`（切换公司，`navigateToCompanyPage`，注意无参调用，详见 9.2）
  - `TenantManagePage`（租户管理，`navigateToTenantManagePage`）
  - `UserManagePage`（用户管理，`navigateToUserManagePage`）
- **依赖组件**：`UI/Components/CustomDialog.swift`（`CustomDialog`、`CustomSelectionDialog`、`CustomDatePickerDialog`）
- **依赖模型**：`Models/User.swift`、`Models/Company.swift`（权限判断）、`Models/Tenant.swift`（导航标题与租户角色）
- **依赖服务**：`HTTPClient.shared.updateUser(...)`、`HTTPClient.shared.updateAvatar(...)`、`AppState.shared`（`currentTenant` / `currentCompany` / `userData` / `updateUserData` / `clearUserData`）

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `appState` | `@ObservedObject` (`AppState`) | `AppState.shared` | 全局状态：当前租户/公司/用户 |
| `dismiss` | `@Environment` | — | 关闭本页（fullScreenCover 返回） |
| `userData` | `@State User?` | `nil` | 本页展示与编辑的用户副本 |
| `isLoading` | `@State Bool` | `false` | ⚠️ 声明后未使用（见 10.4） |
| `navigateToCompanyPage` | `@State Bool` | `false` | 控制「切换公司」fullScreenCover |
| `selectedItem` | `@State PhotosPickerItem?` | `nil` | 头像选图结果 |
| `selectedImageData` | `@State Data?` | `nil` | 选中图片二进制（供预览 + 上传） |
| `isUploadingAvatar` | `@State Bool` | `false` | 上传中（头像区显示 `ProgressView`） |
| `showAvatarAlert` | `@State Bool` | `false` | ⚠️ 声明后未使用（见 10.4） |
| `avatarAlertMessage` | `@State String` | `""` | ⚠️ 声明后未使用（见 10.4） |
| `showEditNicknameDialog` | `@State Bool` | `false` | 昵称弹窗 |
| `editNicknameText` | `@State String` | `""` | 昵称输入 |
| `showEditPhoneDialog` | `@State Bool` | `false` | 电话弹窗 |
| `editPhoneText` | `@State String` | `""` | 电话输入 |
| `showEditEmailDialog` | `@State Bool` | `false` | 邮箱弹窗 |
| `editEmailText` | `@State String` | `""` | 邮箱输入 |
| `showGenderDialog` | `@State Bool` | `false` | 性别弹窗 |
| `selectedGender` | `@State String` | `"0"` | 当前性别（`"0"` 男 / `"1"` 女） |
| `genderSelectedIndex` | `@State Int` | `0` | 性别弹窗选中下标 |
| `showEditBirthdayDialog` | `@State Bool` | `false` | 生日弹窗 |
| `selectedBirthday` | `@State Date` | `Date()` | 生日选择值 |
| `showEditRegionDialog` | `@State Bool` | `false` | 地区弹窗 |
| `editRegionText` | `@State String` | `""` | 地区输入 |
| `showEditSignDialog` | `@State Bool` | `false` | 签名弹窗 |
| `editSignText` | `@State String` | `""` | 签名输入（`TextEditor`） |
| `showAlert` | `@State Bool` | `false` | 通用「提示」弹窗 |
| `alertMessage` | `@State String` | `""` | 通用弹窗文案 |
| `showChangePasswordPage` | `@State Bool` | `false` | 「修改密码」fullScreenCover |
| `showLogoutAlert` | `@State Bool` | `false` | 「确认退出」alert |
| `navigateToTenantManagePage` | `@State Bool` | `false` | 「租户管理」fullScreenCover |
| `navigateToUserManagePage` | `@State Bool` | `false` | 「用户管理」fullScreenCover |
| `showAvatarPicker` | `@State Bool` | `false` | `PhotosPicker` 展示开关（声明位置在 601 行 MARK 之后，Swift 允许） |
| `tenantUserRole` | `private var Int`（计算） | — | `appState.currentTenant?.role ?? 0`，控制「租户管理」可见性 |

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar
│   HStack：返回按钮(chevron.left, subColor) ─ Spacer ─ 标题(currentTenant.name 或 "个人信息", middleFont) ─ Spacer ─ 占位按钮(透明, disabled)
│   背景 whiteColor，底部 overlay Rectangle(grayColor.opacity(0.3)) 高 1
├─ ScrollView
│  └─ VStack(spacing: middleMargin)
│     ├─ 资料卡片 VStack(spacing: 0)（whiteColor + borderRadius）
│     │   ├─ avatarRow（头像 + 点击开 photosPicker）
│     │   ├─ DividerLine
│     │   ├─ infoRow("昵称") + DividerLine
│     │   ├─ infoRow("电话") + DividerLine
│     │   ├─ infoRow("邮箱") + DividerLine
│     │   ├─ infoRow("性别", getGenderText) + DividerLine
│     │   ├─ infoRow("出生日期") + DividerLine
│     │   ├─ infoRow("地区") + DividerLine
│     │   └─ infoRow("个性签名")
│     ├─ 「修改密码」按钮（白底黑字，圆角 btnHeight/2）
│     ├─ 「切换公司」按钮
│     ├─ 「用户管理」按钮 ①  if company.isAdmin（role 1 或 2）
│     ├─ 「租户管理」按钮  if tenantUserRole > 0
│     ├─ 「用户管理」按钮 ②  if company.role ?? 0 > 1（role 2）→ 与 ① 重复
│     └─ 「退出登录」按钮（warnColor 文字 + warnColor 描边）
│  └─ background pageBackgroundColor
├─ background pageBackgroundColor
├─ .onAppear { loadUserData() }
├─ .photosPicker(isPresented: $showAvatarPicker, selection: $selectedItem, matching: .images)
│  └─ .onChange(of: selectedItem) { Task { await loadSelectedImage() } }
├─ .overlay(editNicknameDialog) ... .overlay(editSignDialog)   // 7 个弹窗
├─ .alert("提示", isPresented: $showAlert)                     // 通用提示
├─ .alert("确认退出", isPresented: $showLogoutAlert)            // 退出确认（含 .destructive 确定）
├─ .fullScreenCover(isPresented: $showChangePasswordPage) { ChangePasswordPage() }
├─ .fullScreenCover(isPresented: $navigateToCompanyPage) { CompanyPage() }
├─ .fullScreenCover(isPresented: $navigateToTenantManagePage) { TenantManagePage() }
└─ .fullScreenCover(isPresented: $navigateToUserManagePage) { UserManagePage() }
```

子视图拆分：

- `customNavigationBar`：标题取 `appState.currentTenant.name`，无租户时显示「个人信息」。
- `DividerLine()`：`Rectangle` 高 1，`Colors.grayColor.opacity(0.3)`。
- `avatarRow`：左侧「头像」文案，右侧 `Group` 依次判断 `isUploadingAvatar` → `selectedImageData` → `userData.avater`（`AsyncImage`）→ 默认头像，`onTapGesture` 打开 `showAvatarPicker`。
- `defaultAvatarView`：`Colors.primaryColor.opacity(0.7)` 圆底 + 用户名首字符白字。
- `infoRow(label:value:onTap:)`：整行是 `Button`，值空时显示「未设置」灰字，右侧 `chevron.right`。

## 5. 核心方法

### `loadUserData()`
- **触发**：`.onAppear`
- **步骤**：
  1. 从 `appState.userData` 读缓存的用户（**不发起网络请求**，本页不调用 `getUserData`）。
  2. 赋值 `self.userData` 及各编辑态：`editNicknameText / editPhoneText / editEmailText / selectedGender / editRegionText / editSignText`。
  3. `birthday` 若非空，用 `DateFormatter("yyyy-MM-dd")` 解析成 `Date` 写入 `selectedBirthday`。

### `showEditNickname() / showEditPhone() / showEditEmail() / showEditBirthday() / showEditRegion() / showEditSign()`
- **触发**：对应 `infoRow` 的 `onTap`
- **步骤**：把当前 `userData` 的字段回填到对应编辑态，然后置对应 `showXxxDialog = true`。

### `saveUserInfo(completion:)`
- **触发**：各编辑弹窗 `onConfirm`（昵称/电话/邮箱/性别/生日/地区/签名共用）
- **步骤**：
  1. `guard var updatedUser = userData`，为空则 `completion(false)` 直接返回。
  2. 把 7 个编辑态写回 `updatedUser`（`birthday` 用 `formatDate` 转 `"yyyy-MM-dd"`）。
  3. `HTTPClient.shared.updateUser(userData: updatedUser)`。
- **成功**：`self.userData = newUserData`、`appState.updateUserData(newUserData)`、`completion(true)`。
- **失败**：`alertMessage = error.localizedDescription`、`showAlert = true`、`completion(false)`。

### `formatDate(_:)`
- `DateFormatter` 固定 `"yyyy-MM-dd"`，把 `Date` 转字符串。

### `validatePhone(_:)`
- 正则 `^1[3-9]\d{9}$`（大陆手机号），`NSPredicate` 校验。

### `validateEmail(_:)`
- 正则 `[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}`，`NSPredicate` 校验。

### `handleLogout()`
- **触发**：「确认退出」alert 的 `.destructive`「确定」按钮
- **步骤**：
  1. `appState.clearUserData()`（清空内存态 + token + 租户/模型缓存，见 9.3）。
  2. `dismiss()` 关闭本页。
- ⚠️ **不调用后端** `/service/user/logout`，也不清公司缓存，详见 10.5。

### `getFirstCharacter()`
- 取 `userData?.username.first`，无则返回 `"?"`。

### `getGenderText(_:)`
- `"0"` → 男，`"1"` → 女，其它 → 未设置。

### `loadSelectedImage() async`
- **触发**：`.onChange(of: selectedItem)`
- **步骤**：`try await item.loadTransferable(type: Data.self)`，成功后在 `MainActor` 上 `selectedImageData = data` 并 `uploadAvatar(imageData: data)`；失败打印日志。

### `uploadAvatar(imageData:)`
- **触发**：`loadSelectedImage` 成功后
- **步骤**：`isUploadingAvatar = true` → `HTTPClient.shared.updateAvatar(imageData:)` → 回调里 `isUploadingAvatar = false`。
- **成功**：`userData?.avater = avatarUrl`、`appState.updateUserData(updatedUser)`、`alertMessage = "头像更新成功"`、`showAlert = true`。
- **失败**：`alertMessage = error.localizedDescription`、`showAlert = true`、`selectedImageData = nil`（清除预览）。

## 6. 接口调用

| # | HTTPClient 方法 | METHOD | 路径 | 触发时机 | 后端文档 |
|---|---|---|---|---|---|
| 1 | `updateUser` | PUT | `/service/user/updateUser` | 各资料编辑弹窗确认 | `docs/api/user.md` §4 |
| 2 | `updateAvatar` | POST | `/service/user/updateAvater` | 头像选图后自动上传 | `docs/api/user.md` §11 |

### 6.1 `updateUser`

- **Swift 签名**：`func updateUser(userData: User, completion: @escaping (Result<User, NetworkError>) -> Void)`
- **APIEndpoint**：`.updateUser`（`Constants.API.updateUser = "/service/user/updateUser"`，method `PUT`）
- **请求**（Body，`[String: Any]`）：

  | 参数 | 类型 | 说明 |
  |---|---|---|
  | `username` | String | 昵称 |
  | `telephone` | String | 电话 |
  | `email` | String | 邮箱 |
  | `sex` | String | 性别（`"0"`/`"1"`） |
  | `birthday` | String? | 出生日期（`"yyyy-MM-dd"`） |
  | `region` | String | 地区（`userData.region ?? ""`） |
  | `sign` | String | 个性签名 |

- **响应**：`BaseResponse<User>`，`data` 为更新后的 `User`。
- **UI 处理**：成功 → 更新 `self.userData` 与 `appState.userData`；失败 → `showAlert` 提示错误文案。

### 6.2 `updateAvatar`

- **Swift 签名**：`func updateAvatar(imageData: Data, completion: @escaping (Result<String, NetworkError>) -> Void)`
- **APIEndpoint**：`.updateAvater`（`Constants.API.updateAvater = "/service/user/updateAvater"`，method `POST`）。注意端点大小写拼写为 `updateAvater`。
- **请求**：`multipart/form-data`，`Content-Type: multipart/form-data; boundary=Boundary-<UUID>`；文件字段名 `file`，文件名 `avatar_<时间戳>.jpg`，`Content-Type: image/jpeg`。
- **响应**：`BaseResponse<StringData>`，`data.value` 为新头像 URL。
- **UI 处理**：成功 → 回写 `userData.avater` 并同步 `appState`；失败 → 弹提示并清空 `selectedImageData`。

## 7. 数据模型

本页主要使用 `User`（`Models/User.swift`），字段（均为 `Codable`）：

| 字段 | 类型 | 可选 | 说明 |
|---|---|---|---|
| `id` | String? | 是 | 用户 ID |
| `userAccount` | String | 否 | 账号 |
| `username` | String | 否 | 昵称（头像取首字符、卡片展示） |
| `telephone` | String | 否 | 电话 |
| `email` | String | 否 | 邮箱 |
| `avater` | String? | 是 | 头像 URL（注意拼写，后端同） |
| `birthday` | String? | 是 | 出生日期字符串 |
| `sex` | String | 否 | 性别（`"0"` 男 / `"1"` 女） |
| `sign` | String | 否 | 个性签名 |
| `region` | String? | 是 | 地区 |

权限判断另用到：

- `Company`（`role: Int?`，便捷属性 `isAdmin`（1 或 2）/ `isSuperAdmin`（2）/ `isNormalAdmin`（1））
- `Tenant`（`role: Int?`，`name` 用于导航标题）

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 导航栏/卡片/按钮底 | `Colors.whiteColor` |
| 分隔线 | `Colors.grayColor.opacity(0.3)` 高 1 |
| 主按钮文字「确定」、头像底 | `Colors.primaryColor` |
| 退出登录文字/描边 | `Colors.warnColor` |
| 返回箭头 / 次要文字 | `Colors.subColor` |
| 值占位「未设置」/ 右箭头 | `Colors.grayColor` |
| 卡片圆角 | `Dimens.borderRadius` |
| 按钮高 | `Dimens.btnHeight`（圆角 `btnHeight/2`） |
| 输入框高 | `Dimens.inputHeight`（圆角 `inputHeight/2`） |
| 头像尺寸 | `Dimens.bigAvater`（80） |
| 间距 | 统一 `Dimens.middleMargin` |

## 9. 交互流程

### 9.1 编辑资料

```
infoRow 点击 → showEditXxx() 回填 → 弹窗打开
  → onConfirm 校验（昵称非空 / 手机号格式 / 邮箱格式）
  → saveUserInfo { updatedUser 覆盖 7 字段 → updateUser }
      ├─ 成功：userData + appState 更新，弹窗关闭
      └─ 失败：showAlert 提示，弹窗不关闭
```

### 9.2 切换公司

`CompanyPage()` **无参**调用。`CompanyPage` 内部在 `.onAppear` 里以 `appState.currentCompany != nil` 推断 `isFromUserPage = true`（见 `CompanyPage.swift` 181~184 行），据此显示返回按钮并在切换完成后 `dismiss()` 回到本页。即「是否从 UserPage 进入」是**推断**而非参数传入。

### 9.3 退出登录

`handleLogout()` 只做两件事：`appState.clearUserData()` + `dismiss()`。`clearUserData()`（`AppState.swift`）实际清理：

- 内存态：`userData / token / currentTenant / currentModel / currentCompany / tenantList / modelList` 置空，`isLoggedIn = false`。
- 持久化：`TokenManager.shared.clearToken()`（删 `auth_token`）、删除 `tenantIdKey`（`current_tenant_id`）与 `modelIdKey`（`current_model_id`）。
- **不清**：`companyId_<userId>`（`clearCompanyCache` 才删，源码注释「切换账号时需要」）、`currentPrompt` 及按租户的 `current_prompt_id_<tenantId>`。

### 9.4 菜单可见性

| 按钮 | 条件 | 说明 |
|---|---|---|
| 修改密码 / 切换公司 / 退出登录 | 恒显示 | — |
| 用户管理 ① | `appState.currentCompany?.isAdmin`（role 1 或 2） | 正常显示 |
| 租户管理 | `tenantUserRole > 0`（当前租户 role 1 或 2） | 按租户角色 |
| 用户管理 ② | `appState.currentCompany?.role ?? 0 > 1`（role 2） | 与 ① 重复，见 10.3 |

## 10. 二次开发指引

- **改文案/样式**：标题在 `customNavigationBar`；资料行在 `infoRow`；按钮统一在 `body` 里直接写，未抽成独立子视图，可考虑提取为 `private var` 复用。
- **加字段**：`User` 模型（`Models/User.swift`）→ `HTTPClient.updateUser` 的 `parameters` → 本页 `@State` 编辑态 + `loadUserData`/`saveUserInfo` 赋值 → `body` 卡片新增 `infoRow` + 对应弹窗。**注意**：`saveUserInfo` 会一次性覆盖全部字段，新增字段必须在 `saveUserInfo` 里同步赋值，否则会被旧值覆盖。
- **加接口**：`Constants.API` → `APIEndpoint`（`path` + `method`）→ `HTTPClient` 方法 → 本页调用。
- **已知坑 / 注意事项**：
  1. **本页不调用 `getUserData`**：`.onAppear` 的 `loadUserData()` 只读 `appState.userData` 缓存（在登录/选公司阶段已拉取）。若缓存为空，页面显示空值且头像为 `?`，不会自动重拉。
  2. **`isLoading` 声明未使用**（16 行），是死状态。
  3. **重复「用户管理」按钮**：`body` 里有两个「用户管理」按钮，条件分别为 `company.isAdmin`（role 1 或 2）与 `company.role ?? 0 > 1`（role 2）。超级管理员会同时看到两个一模一样的「用户管理」按钮，属明显冗余/复制粘贴遗留。
  4. **`showAvatarAlert` / `avatarAlertMessage` 声明未使用**（23~24 行）：头像上传实际复用 `showAlert` / `alertMessage`，这两个专用于头像的 state 是死代码。
  5. **退出登录不调后端 `/service/user/logout`**：仅本地清理 + `dismiss`。服务端 token 仍有效，且公司缓存 `companyId_<userId>` 被有意保留（`clearUserData` 注释「切换账号时需要」）。
  6. **拼写不统一**：接口端点 `updateAvater`、模型字段 `avater` 均沿用「Avater」拼写，与后端路径一致，改动时不要“顺手修正”以免对不上后端。
  7. **头像固定 `.jpg`**：`updateAvatar` 内文件名与 `Content-Type` 硬编码 `image/jpeg`，而 `PhotosPicker` `matching: .images` 允许选 PNG 等格式，存在格式与声明不符的隐患。
  8. **切换公司非参数传递**：`CompanyPage()` 靠 `appState.currentCompany != nil` 推断 `isFromUserPage`，改动时不要误以为有入参。
