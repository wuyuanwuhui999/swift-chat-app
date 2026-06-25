//
//  TenantManagePage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/7.
//

import SwiftUI

/// 租户管理页面
struct TenantManagePage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 租户用户列表相关状态
    @State private var tenantUsers: [TenantUser] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMoreData = true
    @State private var pageSize = 20
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [TenantUser] = []
    @State private var isSearchLoading = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // 其他状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var tenantUserRole: Int = 0  // 当前登录用户在当前租户内的角色
    @State private var navigateToAddUser = false
    
    // 下拉刷新状态
    @State private var isRefreshing = false
    
    // 记录当前滑动打开的用户ID，用于自动关闭其他打开的条目
    @State private var activeSwipeUserId: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题栏
                customNavigationBar
                
                // 搜索框（直接显示，无卡片包装）
                searchBarView
                
                // 内容区域
                ScrollView {
                    VStack(spacing: Dimens.middleMargin) {
                        // 用户列表卡片
                        userListCardView
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.bottom, Dimens.middleMargin)
                }
                .background(Colors.pageBackgroundColor)
                .refreshable {
                    await refreshData()
                }
            }
            .background(Colors.pageBackgroundColor)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadTenantUserList()
                loadCurrentTenantUserRole()
            }
            .navigationDestination(isPresented: $navigateToAddUser) {
                AddTenantUserPage()
                    .navigationBarHidden(true)
            }
        }
    }
    
    // MARK: - 视图组件
    
    /// 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.primaryColor)
            }
            
            Spacer()
            
            // 标题
            Text("租户管理")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 添加用户按钮（仅当当前用户是超级管理员或管理员时显示）
            if tenantUserRole >= 1 {
                Button(action: {
                    navigateToAddUser = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: Dimens.middleIcon))
                        .foregroundColor(Colors.primaryColor)
                }
            } else {
                // 占位符保持布局
                Color.clear
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    /// 搜索框视图（胶囊型，直接显示）
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Colors.grayColor)
                    .font(.system(size: Dimens.smallIcon))
                
                TextField("搜索用户", text: $searchText)
                    .font(.system(size: Dimens.normalFont))
                    .onChange(of: searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Colors.grayColor)
                            .font(.system(size: Dimens.smallIcon))
                    }
                }
            }
            .padding(.horizontal, Dimens.middleMargin)
            .frame(height: Dimens.inputHeight)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.inputHeight / 2)
            .overlay(
                RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                    .stroke(Colors.grayColor.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    /// 用户列表卡片视图
    @ViewBuilder
    private var userListCardView: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if (isSearching ? searchResults.isEmpty : tenantUsers.isEmpty) {
                emptyStateView
            } else {
                // 用户列表
                userListView
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 用户列表视图
    @ViewBuilder
    private var userListView: some View {
        let users = isSearching ? searchResults : tenantUsers
        
        LazyVStack(spacing: 0) {
            ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                SwipeableTenantUserRow(
                    tenantUser: user,
                    currentUserRole: tenantUserRole,
                    isActiveSwipe: activeSwipeUserId == user.id,
                    onSwipeStateChanged: { userId, isOpen in
                        if isOpen {
                            // 关闭其他打开的条目
                            if let currentActive = activeSwipeUserId, currentActive != userId {
                                activeSwipeUserId = nil
                            }
                            activeSwipeUserId = userId
                        } else {
                            if activeSwipeUserId == userId {
                                activeSwipeUserId = nil
                            }
                        }
                    },
                    onDelete: {
                        deleteTenantUser(user)
                    },
                    onRoleChange: {
                        toggleAdminStatus(user)
                    }
                )
                
                if index < users.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器（仅在非搜索模式下）
            if !isSearching && hasMoreData && !isLoadingMore && !isRefreshing {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMoreTenantUsers()
                    }
            }
            
            // 搜索加载更多
            if isSearching && isSearchLoading {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
            }
        }
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "person.slash")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text(isSearching ? "未找到相关用户" : "暂无用户")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    // MARK: - 搜索方法
    
    /// 处理搜索文本变化（防抖）
    private func handleSearchTextChange(_ newValue: String) {
        // 取消之前的任务
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            // 清空搜索，显示列表
            isSearching = false
            searchResults = []
            return
        }
        
        // 创建新的延时任务
        let workItem = DispatchWorkItem {
            self.performSearch(keyword: newValue)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 执行搜索（复用 getTenantUserList 接口）
    private func performSearch(keyword: String) {
        guard let tenantId = appState.currentTenant?.id else { return }
        
        isSearching = true
        isSearchLoading = true
        
        HTTPClient.shared.getTenantUserList(
            tenantId: tenantId,
            keyword: keyword,
            pageNum: 1,
            pageSize: 100
        ) { result in
            DispatchQueue.main.async {
                self.isSearchLoading = false
                
                switch result {
                case .success(let (users, _)):
                    self.searchResults = users
                case .failure(let error):
                    print("❌ 搜索用户失败: \(error.localizedDescription)")
                    self.searchResults = []
                }
            }
        }
    }
    
    // MARK: - 数据加载方法
    
    /// 下拉刷新
    private func refreshData() async {
        await MainActor.run {
            isRefreshing = true
            // 刷新时关闭所有滑动打开的条目
            activeSwipeUserId = nil
        }
        
        // 重置状态
        currentPage = 1
        hasMoreData = true
        
        if isSearching {
            // 如果正在搜索，重新执行搜索
            performSearch(keyword: searchText)
        } else {
            // 重新加载租户用户列表
            loadTenantUserList(reset: true)
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    /// 加载当前用户在当前租户内的角色
    private func loadCurrentTenantUserRole() {
        guard let tenantId = appState.currentTenant?.id else { return }
        
        HTTPClient.shared.getTenantUser(tenantId: tenantId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tenantUser):
                    self.tenantUserRole = tenantUser.role
                case .failure(let error):
                    print("❌ 获取租户用户角色失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 加载租户用户列表
    private func loadTenantUserList(reset: Bool = true) {
        guard let tenantId = appState.currentTenant?.id else {
            print("❌ 未找到租户ID")
            return
        }
        
        if reset {
            isLoading = true
            currentPage = 1
            tenantUsers = []
            hasMoreData = true
            // 刷新时关闭所有滑动打开的条目
            activeSwipeUserId = nil
        }
        
        HTTPClient.shared.getTenantUserList(
            tenantId: tenantId,
            pageNum: currentPage,
            pageSize: pageSize
        ) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let (users, total)):
                    if reset {
                        self.tenantUsers = users
                    } else {
                        // 去重添加
                        let existingIds = Set(self.tenantUsers.map { $0.id })
                        let newUsers = users.filter { !existingIds.contains($0.id) }
                        self.tenantUsers.append(contentsOf: newUsers)
                    }
                    // 判断是否还有更多数据
                    self.hasMoreData = self.tenantUsers.count < total
                    print("✅ 获取租户用户列表成功，共 \(users.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 获取租户用户列表失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    /// 加载更多租户用户
    private func loadMoreTenantUsers() {
        guard !isLoadingMore && hasMoreData && !isSearching else { return }
        isLoadingMore = true
        currentPage += 1
        loadTenantUserList(reset: false)
    }
    
    // MARK: - 用户操作
    
    /// 删除租户用户
    private func deleteTenantUser(_ user: TenantUser) {
        // 显示确认对话框
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要将用户 \"\(user.username)\" 从租户中移除吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            performDeleteUser(user)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 执行删除用户
    private func performDeleteUser(_ user: TenantUser) {
        // 从列表中移除
        if isSearching {
            searchResults.removeAll { $0.id == user.id }
            // 同时从主列表中移除
            tenantUsers.removeAll { $0.id == user.id }
        } else {
            tenantUsers.removeAll { $0.id == user.id }
        }
        
        alertMessage = "用户已移除"
        showAlert = true
    }
    
    /// 切换管理员状态
    private func toggleAdminStatus(_ user: TenantUser) {
        guard let tenantId = appState.currentTenant?.id else { return }
        
        let isAdmin = user.role == 1
        
        if isAdmin {
            // 取消管理员
            HTTPClient.shared.cancelAdmin(tenantId: tenantId, userId: user.userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let success):
                        if success {
                            self.alertMessage = "已取消管理员权限"
                            self.showAlert = true
                            // 刷新列表
                            self.refreshLocalUserRole(user, newRoleType: 0)
                        } else {
                            self.alertMessage = "操作失败"
                            self.showAlert = true
                        }
                    case .failure(let error):
                        self.alertMessage = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
        } else {
            // 设为管理员
            HTTPClient.shared.addAdmin(tenantId: tenantId, userId: user.userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let success):
                        if success {
                            self.alertMessage = "已设为管理员"
                            self.showAlert = true
                            // 刷新列表
                            self.refreshLocalUserRole(user, newRoleType: 1)
                        } else {
                            self.alertMessage = "操作失败"
                            self.showAlert = true
                        }
                    case .failure(let error):
                        self.alertMessage = error.localizedDescription
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    /// 刷新本地用户角色
    private func refreshLocalUserRole(_ user: TenantUser, newRoleType: Int) {
        // 更新主列表
        if let index = tenantUsers.firstIndex(where: { $0.id == user.id }) {
            let newUser = TenantUser(
                id: tenantUsers[index].id,
                tenantId: tenantUsers[index].tenantId,
                tenantName: tenantUsers[index].tenantName,
                userId: tenantUsers[index].userId,
                userAccount: tenantUsers[index].userAccount,
                role: newRoleType,
                joinDate: tenantUsers[index].joinDate,
                createBy: tenantUsers[index].createBy,
                username: tenantUsers[index].username,
                avater: tenantUsers[index].avater,
                disabled: tenantUsers[index].disabled,
                email: tenantUsers[index].email
            )
            tenantUsers[index] = newUser
        }
        
        // 更新搜索结果列表
        if let index = searchResults.firstIndex(where: { $0.id == user.id }) {
            let newUser = TenantUser(
                id: searchResults[index].id,
                tenantId: searchResults[index].tenantId,
                tenantName: searchResults[index].tenantName,
                userId: searchResults[index].userId,
                userAccount: searchResults[index].userAccount,
                role: newRoleType,
                joinDate: searchResults[index].joinDate,
                createBy: searchResults[index].createBy,
                username: searchResults[index].username,
                avater: searchResults[index].avater,
                disabled: searchResults[index].disabled,
                email: searchResults[index].email
            )
            searchResults[index] = newUser
        }
    }
}

// MARK: - 可滑动租户用户行组件（支持双向滑动恢复）

/// 可滑动租户用户行视图
struct SwipeableTenantUserRow: View {
    let tenantUser: TenantUser
    let currentUserRole: Int  // 当前登录用户角色 (0:普通, 1:管理员, 2:超级管理员)
    let isActiveSwipe: Bool
    let onSwipeStateChanged: (String, Bool) -> Void
    let onDelete: () -> Void
    let onRoleChange: () -> Void
    
    // 滑动偏移量
    @State private var offset: CGFloat = 0
    // 拖拽起始位置
    @State private var dragStartLocation: CGFloat = 0
    
    // 计算滑动操作区域的宽度
    private var actionButtonsWidth: CGFloat {
        var width: CGFloat = 0
        if showAdminButton {
            width += 100  // 设为管理员/取消管理员按钮宽度
        }
        if showDeleteButton {
            width += 70   // 删除按钮宽度
        }
        return width
    }
    
    // 当前用户是否为超级管理员
    private var isSuperAdmin: Bool {
        return currentUserRole == 2
    }
    
    // 当前用户是否为普通管理员
    private var isNormalAdmin: Bool {
        return currentUserRole == 1
    }
    
    // 当前用户是否为普通用户
    private var isNormalUser: Bool {
        return currentUserRole == 0
    }
    
    // 目标用户是否为超级管理员
    private var targetIsSuperAdmin: Bool {
        return tenantUser.role == 2
    }
    
    // 目标用户是否为管理员
    private var targetIsAdmin: Bool {
        return tenantUser.role == 1
    }
    
    // 目标用户是否为普通用户
    private var targetIsNormalUser: Bool {
        return tenantUser.role == 0
    }
    
    // 是否显示管理员操作按钮
    // 只有当前登录用户是超级管理员时，才显示设为管理员/取消管理员按钮
    private var showAdminButton: Bool {
        guard isSuperAdmin else { return false }
        // 不能对超级管理员进行操作
        return !targetIsSuperAdmin
    }
    
    // 管理员按钮文本
    private var adminButtonText: String {
        return targetIsAdmin ? "取消管理员" : "设为管理员"
    }
    
    // 是否显示删除按钮
    // 规则：
    // 1. 当前用户是超级管理员：可以对所有人显示删除按钮（但不能删除自己）
    // 2. 当前用户是普通管理员：只对普通用户显示删除按钮（不能删除管理员和超级管理员，也不能删除自己）
    // 3. 当前用户是普通用户：不显示删除按钮
    private var showDeleteButton: Bool {
        if targetIsSuperAdmin {
            return false  // 不能删除超级管理员
        }
        
        if isSuperAdmin {
            // 超级管理员不能删除自己
            return tenantUser.userId != appState.userData?.id
        }
        
        if isNormalAdmin {
            // 普通管理员只能删除普通用户，不能删除其他管理员，也不能删除自己
            return targetIsNormalUser && tenantUser.userId != appState.userData?.id
        }
        
        return false
    }
    
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景层（滑动时显示的删除和角色按钮）
                HStack(spacing: 0) {
                    Spacer()
                    
                    // 管理员操作按钮（仅当超级管理员且目标不是超级管理员时显示）
                    if showAdminButton {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                resetOffset()
                            }
                            onRoleChange()
                        }) {
                            Text(adminButtonText)
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.white)
                                .frame(width: 100, height: geometry.size.height)
                                .background(Colors.primaryColor)
                        }
                    }
                    
                    // 删除按钮
                    if showDeleteButton {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                resetOffset()
                            }
                            onDelete()
                        }) {
                            Text("删除")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.white)
                                .frame(width: 70, height: geometry.size.height)
                                .background(Colors.warnColor)
                        }
                    }
                }
                
                // 前景层（可滑动的用户信息卡片）
                HStack(spacing: Dimens.middleMargin) {
                    // 用户头像
                    UserAvatar(
                        avatarUrl: tenantUser.avater,
                        username: tenantUser.username,
                        size: Dimens.middleAvater
                    )
                    
                    // 用户信息
                    VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                        Text(tenantUser.username)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.primary)
                        
                        Text(tenantUser.userAccount)
                            .font(.system(size: Dimens.normalFont - 2))
                            .foregroundColor(Colors.grayColor)
                    }
                    
                    Spacer()
                    
                    // 管理员标签
                    if tenantUser.shouldShowRoleTag {
                        Text(tenantUser.roleText)
                            .font(.system(size: Dimens.normalFont - 4))
                            .foregroundColor(Colors.primaryColor)
                            .padding(.horizontal, Dimens.smallIcon)
                            .padding(.vertical, 4)
                            .background(Colors.primaryColor.opacity(0.1))
                            .cornerRadius(Dimens.smallIcon)
                    }
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
                .background(Colors.whiteColor)
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            let newOffset = value.translation.width
                            
                            // 只允许向左滑动（负值）
                            if newOffset < 0 {
                                // 限制最大滑动距离不超过按钮总宽度
                                let maxOffset = -actionButtonsWidth
                                offset = max(newOffset, maxOffset)
                            } else if newOffset > 0 && offset < 0 {
                                // 向右滑动时，如果当前已经向左滑开，则恢复
                                offset = min(0, offset + newOffset)
                            }
                            
                            dragStartLocation = value.startLocation.x
                        }
                        .onEnded { value in
                            let threshold: CGFloat = actionButtonsWidth / 2
                            
                            if offset < -threshold {
                                // 完全展开
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = -actionButtonsWidth
                                }
                                onSwipeStateChanged(tenantUser.id, true)
                            } else {
                                // 复位
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    resetOffset()
                                }
                            }
                        }
                )
                .onTapGesture {
                    // 点击时复位
                    if offset < 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            resetOffset()
                        }
                    }
                }
            }
            .frame(height: Dimens.middleAvater + Dimens.middleMargin * 2)
            .clipped()
        }
        .frame(height: Dimens.middleAvater + Dimens.middleMargin * 2)
        .onChange(of: isActiveSwipe) { newValue in
            if !newValue && offset < 0 {
                // 当其他条目打开时，关闭当前条目
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    resetOffset()
                }
            }
        }
    }
    
    /// 复位偏移量
    private func resetOffset() {
        offset = 0
        onSwipeStateChanged(tenantUser.id, false)
    }
}

#Preview {
    TenantManagePage()
}