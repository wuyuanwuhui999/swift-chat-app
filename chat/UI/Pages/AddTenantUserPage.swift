//
//  AddTenantUserPage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/9.
//

import SwiftUI

/// 添加租户用户页面（独立页面）
struct AddTenantUserPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearchLoading = false
    @State private var searchWorkItem: DispatchWorkItem?
    @State private var currentPage = 1
    @State private var pageSize = 20
    @State private var hasMoreData = true
    @State private var isLoadingMore = false
    
    // 已添加的用户ID集合
    @State private var addedUserIds: Set<String> = []
    // 正在添加的用户ID集合（用于显示加载状态）
    @State private var addingUserIds: Set<String> = []
    
    // 提示相关
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 下拉刷新状态
    @State private var isRefreshing = false
    
    var body: some View {
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
            loadAddedUsers()
        }
        .navigationBarHidden(true)
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
            Text("添加用户")
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
    
    /// 搜索框视图（胶囊型，直接显示）
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Colors.grayColor)
                    .font(.system(size: Dimens.smallIcon))
                
                TextField("搜索用户（姓名或工号）", text: $searchText)
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
            if isSearchLoading && searchResults.isEmpty {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                emptyStateView
            } else if searchResults.isEmpty {
                emptySearchView
            } else {
                userListView
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 用户列表视图
    @ViewBuilder
    private var userListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, user in
                UserSearchRow(
                    user: user,
                    isAdded: addedUserIds.contains(user.id ?? ""),
                    isAdding: addingUserIds.contains(user.id ?? ""),
                    onAdd: {
                        addUserToTenant(user)
                    }
                )
                
                if index < searchResults.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器
            if hasMoreData && !isLoadingMore && !isRefreshing && !searchText.isEmpty {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMoreUsers()
                    }
            }
        }
    }
    
    /// 空状态视图（搜索无结果）
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "person.slash")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text("未找到相关用户")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
            
            Text("请尝试其他关键词")
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 空状态视图（未搜索）
    private var emptySearchView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text("输入姓名或工号搜索用户")
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
            // 清空搜索结果
            searchResults = []
            hasMoreData = true
            currentPage = 1
            return
        }
        
        // 重置分页
        currentPage = 1
        hasMoreData = true
        searchResults = []
        
        // 创建新的延时任务
        let workItem = DispatchWorkItem {
            self.performSearch(reset: true)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 执行搜索
    private func performSearch(reset: Bool = true) {
        guard !searchText.isEmpty else { return }
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        if reset {
            isSearchLoading = true
            currentPage = 1
            searchResults = []
        }
        
        HTTPClient.shared.searchCompanyUsers(
            keyword: searchText,
            companyId: companyId,
            pageNum: currentPage,
            pageSize: pageSize
        ) { result in
            DispatchQueue.main.async {
                self.isSearchLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let (users, total)):
                    if reset {
                        self.searchResults = users
                    } else {
                        // 去重添加
                        let existingIds = Set(self.searchResults.compactMap { $0.id })
                        let newUsers = users.filter { user in
                            guard let id = user.id else { return false }
                            return !existingIds.contains(id)
                        }
                        self.searchResults.append(contentsOf: newUsers)
                    }
                    // 判断是否还有更多数据
                    self.hasMoreData = self.searchResults.count < total
                    print("✅ 搜索用户成功，共 \(users.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 搜索用户失败: \(error.localizedDescription)")
                    if reset {
                        self.searchResults = []
                    }
                }
            }
        }
    }
    
    /// 加载更多用户
    private func loadMoreUsers() {
        guard !isLoadingMore && hasMoreData && !searchText.isEmpty else { return }
        isLoadingMore = true
        currentPage += 1
        performSearch(reset: false)
    }
    
    /// 下拉刷新
    private func refreshData() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        if !searchText.isEmpty {
            performSearch(reset: true)
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    // MARK: - 数据加载方法
    
    /// 加载已添加的用户列表
    private func loadAddedUsers() {
        guard let tenantId = appState.currentTenant?.id else { return }
        
        // 获取租户下的所有用户，记录已添加的用户ID
        HTTPClient.shared.getTenantUserList(
            tenantId: tenantId,
            pageNum: 1,
            pageSize: 1000
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (users, _)):
                    let userIds = users.map { $0.userId }
                    self.addedUserIds = Set(userIds)
                case .failure(let error):
                    print("❌ 获取已添加用户列表失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 添加用户
    
    /// 添加用户到租户
    private func addUserToTenant(_ user: User) {
        guard let tenantId = appState.currentTenant?.id,
              let userId = user.id else { return }
        
        // 防止重复点击
        guard !addingUserIds.contains(userId) else { return }
        
        // 标记为正在添加
        addingUserIds.insert(userId)
        
        HTTPClient.shared.addTenantUser(tenantId: tenantId, userId: userId) { result in
            DispatchQueue.main.async {
                // 移除正在添加标记
                self.addingUserIds.remove(userId)
                
                switch result {
                case .success(let data):
                    if data > 0 {
                        // 添加成功
                        self.alertMessage = "添加成功"
                        self.showAlert = true
                        // 标记为已添加
                        self.addedUserIds.insert(userId)
                    } else {
                        // data <= 0 表示添加失败
                        self.alertMessage = "添加失败，请稍后重试"
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

// MARK: - 用户搜索行组件

/// 用户搜索行视图
struct UserSearchRow: View {
    let user: User
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 用户头像
            UserAvatar(
                avatarUrl: user.avater,
                username: user.username,
                size: Dimens.middleAvater
            )
            
            // 用户信息
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                Text(user.username)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                
                Text(user.userAccount)
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }
            
            Spacer()
            
            // 添加按钮 / 已添加标签 / 加载状态
            if isAdded {
                Text("已添加")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.smallMargin)
                    .background(Colors.grayColor.opacity(0.2))
                    .cornerRadius(Dimens.borderRadius * 2)
            } else if isAdding {
                // 加载状态
                ProgressView()
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
            } else {
                Button(action: onAdd) {
                    Text("添加")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.whiteColor)
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.smallMargin)
                        .background(Colors.primaryColor)
                        .cornerRadius(Dimens.borderRadius * 2)
                }
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
}

#Preview {
    AddTenantUserPage()
}