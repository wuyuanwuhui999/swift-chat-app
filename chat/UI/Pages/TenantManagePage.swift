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
    @State private var searchResults: [UserData] = []
    @State private var isSearchLoading = false
    
    // 其他状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var tenantUserRole: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            customNavigationBar
            
            // 内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 搜索框卡片
                    searchCardView
                    
                    // 用户列表卡片
                    userListCardView
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
                .padding(.bottom, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
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
            
            // 占位按钮，保持标题居中
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(.clear)
            }
            .disabled(true)
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
    
    /// 搜索框卡片视图
    private var searchCardView: some View {
        // 搜索输入框
        HStack(spacing: Dimens.middleMargin) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Colors.grayColor)
                .font(.system(size: Dimens.smallIcon))
            
            TextField("搜索用户（姓名或工号）", text: $searchText)
                .font(.system(size: Dimens.normalFont))
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty && isSearching {
                        clearSearch()
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    clearSearch()
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
    
    /// 用户列表卡片视图
    @ViewBuilder
    private var userListCardView: some View {
        VStack(spacing: 0) {
            if isLoading && tenantUsers.isEmpty && !isSearching {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if isSearching {
                // 搜索结果列表
                searchResultListView
            } else if tenantUsers.isEmpty {
                emptyStateView
            } else {
                // 租户用户列表
                tenantUserListView
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "person.slash")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text("暂无用户")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 搜索结果列表视图
    @ViewBuilder
    private var searchResultListView: some View {
        if isSearchLoading {
            ProgressView()
                .padding(.vertical, Dimens.largeMargin)
        } else if searchResults.isEmpty {
            VStack(spacing: Dimens.middleMargin) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: Dimens.bigIcon))
                    .foregroundColor(Colors.grayColor)
                
                Text("未找到相关用户")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.grayColor)
            }
            .padding(.vertical, Dimens.largeMargin)
        } else {
            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, user in
                SearchResultRow(
                    user: user,
                    onAdd: {
                        addUserToTenant(user)
                    }
                )
                
                if index < searchResults.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
        }
    }
    
    /// 租户用户列表视图
    @ViewBuilder
    private var tenantUserListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tenantUsers.enumerated()), id: \.offset) { index, user in
                TenantUserRow(tenantUser: user)
                
                if index < tenantUsers.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器
            if hasMoreData && !isLoadingMore && !isSearching {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMoreTenantUsers()
                    }
            }
        }
    }
    
    // MARK: - 数据加载方法
    
    /// 加载当前用户在当前租户内的角色
    private func loadCurrentTenantUserRole() {
        guard let tenantId = appState.currentTenant?.id else { return }
        
        HTTPClient.shared.getTenantUser(tenantId: tenantId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tenantUser):
                    self.tenantUserRole = tenantUser.roleType
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
    
    /// 执行搜索
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            clearSearch()
            return
        }
        
        isSearchLoading = true
        isSearching = true
        
        HTTPClient.shared.searchCompanyUsers(keyword: searchText) { result in
            DispatchQueue.main.async {
                self.isSearchLoading = false
                
                switch result {
                case .success(let users):
                    self.searchResults = users
                    if users.isEmpty {
                        self.alertMessage = "未找到相关用户"
                        self.showAlert = true
                    }
                case .failure(let error):
                    print("❌ 搜索用户失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.isSearching = false
                }
            }
        }
    }
    
    /// 清除搜索
    private func clearSearch() {
        isSearching = false
        searchResults = []
        searchText = ""
    }
    
    /// 添加用户到租户
    private func addUserToTenant(_ user: UserData) {
        guard let tenantId = appState.currentTenant?.id,
              let userId = user.id else {
            alertMessage = "缺少必要参数"
            showAlert = true
            return
        }
        
        HTTPClient.shared.addTenantUser(tenantId: tenantId, userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if data > 0 {
                        self.alertMessage = "添加成功"
                        self.showAlert = true
                        // 清除搜索，刷新租户用户列表
                        self.clearSearch()
                        self.loadTenantUserList()
                    } else {
                        self.alertMessage = "添加失败"
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

// MARK: - 租户用户行组件

/// 租户用户行视图
struct TenantUserRow: View {
    let tenantUser: TenantUser
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 用户头像
            UserAvatar(
                avatarUrl: tenantUser.avater,
                username: tenantUser.username,
                size: Dimens.middleAvater
            )
            
            // 用户姓名 + 角色标签
            Text(tenantUser.username)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.primary)
            
            Text(tenantUser.userAccount)
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)

            if tenantUser.shouldShowRoleTag {
                Text(tenantUser.roleText)
                    .font(.system(size: Dimens.normalFont - 4))
                    .foregroundColor(Colors.primaryColor)
                    .padding(.horizontal, Dimens.smallIcon)
                    .padding(.vertical, 4)
                    .background(Colors.primaryColor.opacity(0.1))
                    .cornerRadius(Dimens.smallIcon)
                    .fixedSize()  // 确保标签完整显示
                Spacer(minLength: 0)
            }else{
                Spacer()
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
}

// MARK: - 搜索结果行组件

/// 搜索结果行视图
struct SearchResultRow: View {
    let user: UserData
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 用户头像
            UserAvatar(
                avatarUrl: user.avater,
                username: user.username,
                size: Dimens.middleAvater
            )
            
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                // 用户姓名
                Text(user.username)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                
                // 工号（使用用户ID作为工号）
                Text("工号：\(user.id ?? "")")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }
            
            Spacer()
            
            // 添加按钮
            Button(action: onAdd) {
                Text("添加")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.whiteColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .frame(height: Dimens.smallBtnHeight)
                    .background(Colors.primaryColor)
                    .cornerRadius(Dimens.smallBtnHeight / 2)
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
}

#Preview {
    TenantManagePage()
}
