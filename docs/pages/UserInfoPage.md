---
name: user-info-page
description: 公司成员资料详情页（只读）—— 展示单个 CompanyUser 的完整档案（头像/姓名/工号/角色/电话/邮箱/性别/部门/职位/地区/签名/加入时间），由用户管理页进入。改动该页前先读本文档。
page: UserInfoPage.swift
path: chat/chat/UI/Pages/UserInfoPage.swift
apis: []
---

# UserInfoPage（用户信息详情页）

## 1. 页面职责

`UserInfoPage` 是**只读**的公司成员资料详情页：接收一个 `CompanyUser` 对象，把其档案字段逐行展示在卡片里，供管理员查看成员信息。它**不编辑任何字段、不上传头像、不调用任何接口**，纯展示。

> ⚠️ 与直觉不同：本页**不是**「个人资料编辑页」。当前登录用户编辑自己的资料、上传头像是在 [UserPage](UserPage.md) 里完成的；本页是查看**公司其他成员**资料的详情页。

## 2. 位置与依赖

- **源码**：`chat/chat/UI/Pages/UserInfoPage.swift`（316 行）
- **入口**：`UserManagePage`（用户管理）的 `navigationDestination`。列表点击某一成员后 `selectedUser` 赋值并 `showUserInfoPage = true`：

  ```swift
  .navigationDestination(isPresented: $showUserInfoPage) {
      if let user = selectedUser {
          UserInfoPage(companyUser: user)
              .navigationBarHidden(true)
      }
  }
  ```

  因此本页在 `UserManagePage` 的 `NavigationStack` 内被 push，返回用 `dismiss()`。
- **出口**：无（只读页，仅返回）。
- **依赖组件**：无（自绘 `avatarRow` / `infoRow` / `DividerLine`，未复用 `UserAvatar`）。
- **依赖模型**：`Models/CompanyUser.swift`
- **依赖服务**：无（不调用 `HTTPClient` / `AppState` / `TokenManager`）。

## 3. 状态定义

| 属性 | 类型 | 初值 | 作用 |
|---|---|---|---|
| `dismiss` | `@Environment` | — | 关闭本页（返回上一页） |
| `companyUser` | `let CompanyUser`（入参） | — | 要展示的公司成员数据 |

本页没有任何 `@State`，是纯无状态视图，渲染完全由入参 `companyUser` 决定。

## 4. 视图结构

```
body: VStack(spacing: 0)
├─ customNavigationBar（返回按钮 + 标题「用户信息」+ 占位按钮，底部 1px 分隔线）
├─ ScrollView
│  └─ VStack(spacing: middleMargin)
│     └─ userInfoCard（whiteColor + borderRadius）
│        ├─ avatarRow（头像 AsyncImage / 默认文字头像）
│        ├─ DividerLine
│        ├─ infoRow("姓名", companyUser.username)
│        ├─ infoRow("工号", companyUser.userAccount)
│        ├─ infoRow("角色", companyUser.roleText)
│        ├─ infoRow("电话", telephone 空则"未设置")
│        ├─ infoRow("邮箱", email 空则"未设置")
│        ├─ infoRow("性别", getGenderText(companyUser.sex))
│        ├─ infoRow("部门", companyUser.displayDepartment)
│        ├─ infoRow("职位", companyUser.displayPosition)
│        ├─ infoRow("地区", region 空则"未设置")
│        ├─ infoRow("个性签名", sign 空则"未设置")
│        └─ infoRow("加入时间", formatJoinDate(companyUser.joinDate))
├─ background pageBackgroundColor
└─ .navigationBarHidden(true)
```

- `customNavigationBar`：返回箭头为 `Colors.primaryColor`（注意与 `UserPage`/`ChangePasswordPage` 的 `Colors.subColor` 不同），标题「用户信息」。
- `avatarRow`：`companyUser.avater` 非空时 `AsyncImage`（`Constants.baseURL + avatarUrl`），否则 `defaultAvatarView`。
- `defaultAvatarView`：`Colors.primaryColor.opacity(0.7)` 圆底 + 用户名首字符。
- `infoRow(label:value:)`：左侧 label 固定宽 80 左对齐，右侧 value 右对齐、`lineLimit(3)`，值为「未设置」时灰字。
- `DividerLine()`：高 1，`Colors.grayColor.opacity(0.3)`，仅 `padding(.leading)`。

## 5. 核心方法

### `getFirstCharacter()`
- 取 `companyUser.username.first`，无则 `"?"`，用于默认文字头像。

### `getGenderText(_:)`
- `"0"` → 男，`"1"` → 女，其它 → 未设置。

### `formatJoinDate(_:)`
- **触发**：渲染「加入时间」行时调用
- **步骤**：依次尝试三种 `DateFormatter`（`en_US_POSIX`、`TimeZone.current`）解析入参字符串：
  1. `"yyyy-MM-dd'T'HH:mm:ss"`（ISO 8601）
  2. `"yyyy-MM-dd HH:mm:ss"`
  3. `"yyyy-MM-dd"`（纯日期）
- 解析成功后统一用 `"yyyy-MM-dd"` 输出；全部失败或入参为空时返回原文或 `"未设置"`。

## 6. 接口调用

无。本页不发起任何网络请求，数据全部来自入参 `companyUser`。

> 该对象由 `UserManagePage` 通过 `HTTPClient.getCompanyUsers(...)` / `searchCompanyUsers(...)` 拉取得到（接口见 `docs/api/company.md` §2/§3），本页只负责渲染。

## 7. 数据模型

`CompanyUser`（`Models/CompanyUser.swift`，`Codable, Identifiable`）本页用到的字段：

| 字段 | 类型 | 可选 | 展示用途 |
|---|---|---|---|
| `id` | String? | 是 | — |
| `username` | String | 否 | 姓名、头像首字符 |
| `userAccount` | String | 否 | 工号 |
| `telephone` | String | 否 | 电话 |
| `email` | String | 否 | 邮箱 |
| `sex` | String | 否 | 性别（`"0"`/`"1"`） |
| `region` | String? | 是 | 地区 |
| `avater` | String? | 是 | 头像 URL |
| `sign` | String | 否 | 个性签名 |
| `departmentName` | String? | 是 | 部门（经 `displayDepartment`） |
| `positionName` | String? | 是 | 职位（经 `displayPosition`） |
| `role` | Int? | 是 | 角色（经 `roleText`：2 超管 / 1 管理员 / 其它 普通成员） |
| `joinDate` | String? | 是 | 加入时间（经 `formatJoinDate`） |

便捷属性（`CompanyUser` 内实现）：`displayDepartment`（`departmentName ?? "未分配"`）、`displayPosition`（`positionName ?? "未分配"`）、`roleText`、`shouldShowRoleTag`（`role > 0`）。

## 8. 样式落地清单

| 元素 | 常量 |
|---|---|
| 页面背景 | `Colors.pageBackgroundColor` |
| 卡片 / 导航栏底 | `Colors.whiteColor` |
| 卡片圆角 | `Dimens.borderRadius` |
| 返回箭头 / 头像底 | `Colors.primaryColor` |
| 分隔线 | `Colors.grayColor.opacity(0.3)` 高 1 |
| 「未设置」占位字 | `Colors.grayColor` |
| 标签列宽 | 写死 `80` |
| 头像尺寸 | `Dimens.bigAvater`（80） |
| 间距 | `Dimens.middleMargin` |

## 9. 交互流程

```
UserManagePage 列表点击成员
  → selectedUser = member; showUserInfoPage = true
  → navigationDestination push UserInfoPage(companyUser:)
  → 渲染 userInfoCard（头像 + 13 行信息）
  → 返回按钮 dismiss() 回到 UserManagePage
```

无权限判断、无缓存读写、无网络请求。

## 10. 二次开发指引

- **改文案/样式**：行渲染集中在 `infoRow` 与 `userInfoCard`；标题在 `customNavigationBar`。
- **加字段**：`CompanyUser` 模型（`Models/CompanyUser.swift`）→ `userInfoCard` 新增 `infoRow`。若字段来自后端，需确认 `getCompanyUsers`/`searchUsers` 出参已包含该字段。
- **已知坑 / 注意事项**：
  1. **本页是只读页**，任务描述若称其为「个人资料编辑（含头像上传）」与源码不符——头像上传/资料编辑在 [UserPage](UserPage.md)，本页仅展示 `CompanyUser`。
  2. **返回箭头颜色不一致**：本页返回箭头用 `Colors.primaryColor`，而 `UserPage`、`ChangePasswordPage` 用 `Colors.subColor`，同一批页面视觉不统一。
  3. **未复用 `UserAvatar`** 组件（`UI/Components/UserAvatar.swift`），而是自绘 `avatarRow`/`defaultAvatarView`，与 `UserPage` 的头像逻辑重复。
  4. **空值展示口径不一**：`telephone`/`email`/`region`/`sign` 在 `infoRow` 调用处判断「空则未设置」，而 `role` 经 `roleText` 空值会返回空字符串（非「未设置」）。
  5. `formatJoinDate` 三种格式依次解析，`"yyyy-MM-dd'T'HH:mm:ss"` 未带毫秒/时区，若后端返回带时区或毫秒的 ISO 串会解析失败并回退显示原文。
