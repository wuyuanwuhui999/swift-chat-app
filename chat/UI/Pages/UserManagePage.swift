//
//  UserManagePage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import SwiftUI

/// 用户管理页面
struct UserManagePage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 用户列表相关状态 - 使用 CompanyUser 类型
    @State private var users: [CompanyUser] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMoreData = true
    @State private var pageSize = 20
    
    // 搜索相关状态 - 使用 CompanyUser 类型
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [CompanyUser] = []
    @State private var isSearchLoading = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // 其他状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToAddUser = false
    @State private var selectedUser: CompanyUser?  // 选中的用户
    @State private var showUserInfoPage = false    // 是否显示用户详情页
    
    // 下拉刷新状态
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题栏
                customNavigationBar
                
                // 搜索框
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
                loadCompanyUsers()
            }
            .navigationDestination(isPresented: $navigateToAddUser) {
                AddCompanyUserPage()
                    .navigationBarHidden(true)
            }
            // 跳转到用户详情页
            .navigationDestination(isPresented: $showUserInfoPage) {
                if let user = selectedUser {
                    UserInfoPage(companyUser: user)
                        .navigationBarHidden(true)
                }
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
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            // 标题
            Text("用户管理")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
            // 添加用户按钮
            Button(action: {
                navigateToAddUser = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.subColor)
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
    
    /// 搜索框视图（胶囊型，实时搜索）
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
            if isLoading {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if (isSearching ? searchResults.isEmpty : users.isEmpty) {
                emptyStateView
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
        let displayUsers = isSearching ? searchResults : users
        
        LazyVStack(spacing: 0) {
            ForEach(Array(displayUsers.enumerated()), id: \.element.id) { index, user in
                // 使用新的 UserManageRow 组件显示部门和职位，并添加点击事件
                UserManageRow(companyUser: user)
                    .onTapGesture {
                        selectedUser = user
                        showUserInfoPage = true
                    }
                
                if index < displayUsers.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器（仅非搜索模式且还有更多数据时显示）
            if !isSearching && hasMoreData && !isLoadingMore && !isRefreshing {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMoreUsers()
                    }
            }
            
            // 搜索加载更多指示器
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
    
    // MARK: - 搜索方法（实时搜索，防抖）
    
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
        
        // 创建新的延时任务（0.5秒防抖）
        let workItem = DispatchWorkItem {
            self.performSearch(keyword: newValue)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 执行搜索
    private func performSearch(keyword: String) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        isSearching = true
        isSearchLoading = true
        
        HTTPClient.shared.getCompanyUsers(
            companyId: companyId,
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
        }
        
        // 重置状态
        currentPage = 1
        hasMoreData = true
        
        if isSearching {
            // 如果正在搜索，重新执行搜索
            if !searchText.isEmpty {
                performSearch(keyword: searchText)
            }
        } else {
            // 重新加载公司用户列表
            loadCompanyUsers(reset: true)
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    /// 加载公司用户列表
    private func loadCompanyUsers(reset: Bool = true) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        if reset {
            isLoading = true
            currentPage = 1
            users = []
            hasMoreData = true
        }
        
        HTTPClient.shared.getCompanyUsers(
            companyId: companyId,
            pageNum: currentPage,
            pageSize: pageSize
        ) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let (userList, total)):
                    if reset {
                        self.users = userList
                    } else {
                        // 去重添加
                        let existingIds = Set(self.users.compactMap { $0.id })
                        let newUsers = userList.filter { user in
                            guard let id = user.id else { return false }
                            return !existingIds.contains(id)
                        }
                        self.users.append(contentsOf: newUsers)
                    }
                    // 判断是否还有更多数据
                    self.hasMoreData = self.users.count < total
                    print("✅ 获取公司用户列表成功，共 \(userList.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 获取公司用户列表失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    /// 加载更多用户
    private func loadMoreUsers() {
        guard !isLoadingMore && hasMoreData && !isSearching else { return }
        isLoadingMore = true
        currentPage += 1
        loadCompanyUsers(reset: false)
    }
}

// MARK: - 用户管理行组件（显示部门、职位信息，支持点击）

/// 用户管理行视图
/// 显示用户头像、姓名、角色标签、部门名称、职位名称
struct UserManageRow: View {
    let companyUser: CompanyUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: Dimens.smallMargin) {
            // 第一行：头像 + 用户名 + 角色标签
            HStack(spacing: Dimens.middleMargin) {
                // 用户头像
                UserAvatar(
                    avatarUrl: companyUser.avater,
                    username: companyUser.username,
                    size: Dimens.middleAvater
                )
                VStack(alignment: .leading,spacing: Dimens.middleMargin){
                    HStack(spacing:Dimens.middleMargin){
                        // 用户名
                        Text(companyUser.username)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)
                        // 角色标签（管理员/超级管理员才显示）
                        if companyUser.shouldShowRoleTag {
                            Text(companyUser.roleText)
                                .font(.system(size: Dimens.normalFont - 4))
                                .foregroundColor(Colors.primaryColor)
                                .padding(.horizontal, Dimens.smallIcon)
                                .padding(.vertical, 4)
                                .background(Colors.primaryColor.opacity(0.1))
                                .cornerRadius(Dimens.smallIcon)
                        }
                    }

                    Text(companyUser.userAccount)
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                }
                
                Spacer()
                
                
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .contentShape(Rectangle())  // 确保整个区域可点击
    }
}

#Preview {
    UserManagePage()
}