//
//  AddCompanyUserPage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import SwiftUI

/// 添加用户搜索结果模型
struct SearchUserResult: Codable, Identifiable {
    let id: String?
    let userAccount: String
    let createDate: String?
    let updateDate: String?
    let username: String
    let telephone: String
    let email: String
    let avater: String?
    let birthday: String?
    let sex: String
    let role: String?
    let password: String?
    let sign: String
    let region: String?
    let disabled: Int?
    let permission: Int?
    let checked: Int?  // 0: 不在该公司, 1: 已在该公司
    
    var isAdded: Bool {
        return checked == 1
    }
}

/// 部门模型
struct Department: Codable, Identifiable {
    let id: String
    let companyId: String
    let departmentName: String
    let description: String?
    let createTime: String?
}

/// 职位模型
struct Position: Codable, Identifiable {
    let id: String
    let positionName: String
    let departmentId: String
    let description: String?
    let createTime: String?
}

/// 添加用户页面
struct AddCompanyUserPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [SearchUserResult] = []
    @State private var isSearchLoading = false
    @State private var searchWorkItem: DispatchWorkItem?
    @State private var currentPage = 1
    @State private var pageSize = 20
    @State private var hasMoreData = true
    @State private var isLoadingMore = false
    
    // 已添加的用户ID集合
    @State private var addedUserIds: Set<String> = []
    
    // 添加对话框相关状态
    @State private var showAddDialog = false
    @State private var selectedUser: SearchUserResult?
    @State private var selectedRole = "0"  // 0: 普通用户, 1: 管理员
    @State private var departments: [Department] = []
    @State private var positions: [Position] = []
    @State private var selectedDepartmentId: String?
    @State private var selectedPositionId: String?
    @State private var isLoadingDepartments = false
    @State private var isLoadingPositions = false
    
    // 提示相关
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 下拉刷新状态
    @State private var isRefreshing = false
    
    // MARK: - 计算属性
    
    /// 当前用户是否为超级管理员
    private var isSuperAdmin: Bool {
        return appState.currentCompany?.isSuperAdmin ?? false
    }
    
    /// 当前用户是否为普通管理员
    private var isNormalAdmin: Bool {
        return appState.currentCompany?.isNormalAdmin ?? false
    }
    
    /// 是否显示角色选项（只有超级管理员才显示角色选择）
    private var showRoleOption: Bool {
        return isSuperAdmin
    }
    
    /// 表单是否有效
    private var isFormValid: Bool {
        if isSuperAdmin {
            // 超级管理员需要选择部门和职位
            return selectedDepartmentId != nil && selectedPositionId != nil
        } else {
            // 普通管理员直接添加，不需要验证
            return true
        }
    }
    
    var body: some View {
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
        .overlay(addUserDialog)
        .navigationBarHidden(true)
        .onAppear {
            loadAddedUsers()
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
    
    /// 搜索框视图
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
                AddUserRow(
                    user: user,
                    isAdded: addedUserIds.contains(user.id ?? "") || user.isAdded,
                    onAdd: {
                        selectedUser = user
                        if isSuperAdmin {
                            // 超级管理员，弹出对话框选择角色、部门、职位
                            loadDepartments()
                            showAddDialog = true
                        } else if isNormalAdmin {
                            // 普通管理员，直接添加为普通用户（不需要部门职位）
                            addUserToCompany(user: user, role: 0, positionId: nil)
                        }
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
    
    /// 添加用户对话框
    @ViewBuilder
    private var addUserDialog: some View {
        if showAddDialog, let user = selectedUser {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showAddDialog = false
                        resetDialogState()
                    }
                
                VStack(spacing: Dimens.middleMargin) {
                    // 标题
                    Text("添加用户")
                        .font(.system(size: Dimens.middleFont))
                        .foregroundColor(.primary)
                        .padding(.top, Dimens.middleMargin)
                    
                    // 用户名
                    Text(user.username)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                        .padding(.horizontal, Dimens.middleMargin)
                    
                    // 角色选项（仅超级管理员显示）
                    if showRoleOption {
                        VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                            Text("角色")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: Dimens.middleMargin) {
                                Button(action: {
                                    selectedRole = "0"
                                }) {
                                    HStack(spacing: Dimens.smallIcon) {
                                        Image(systemName: selectedRole == "0" ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(selectedRole == "0" ? Colors.primaryColor : Colors.grayColor)
                                        Text("普通用户")
                                            .font(.system(size: Dimens.normalFont))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    selectedRole = "1"
                                }) {
                                    HStack(spacing: Dimens.smallIcon) {
                                        Image(systemName: selectedRole == "1" ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(selectedRole == "1" ? Colors.primaryColor : Colors.grayColor)
                                        Text("管理员")
                                            .font(.system(size: Dimens.normalFont))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                    }
                    
                    // 部门选择（仅超级管理员显示）
                    if showRoleOption {
                        VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                            Text("部门")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.primary)
                            
                            if isLoadingDepartments {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, Dimens.smallMargin)
                                    Spacer()
                                }
                            } else {
                                Picker("选择部门", selection: $selectedDepartmentId) {
                                    Text("请选择部门").tag(nil as String?)
                                    ForEach(departments) { dept in
                                        Text(dept.departmentName).tag(dept.id as String?)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Dimens.middleMargin)
                                .frame(height: Dimens.inputHeight)
                                .background(Colors.pageBackgroundColor)
                                .cornerRadius(Dimens.inputHeight / 2)
                                .onChange(of: selectedDepartmentId) { newValue in
                                    if let deptId = newValue {
                                        loadPositions(departmentId: deptId)
                                    } else {
                                        positions = []
                                        selectedPositionId = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                    }
                    
                    // 职位选择（仅超级管理员且已选择部门时显示）
                    if showRoleOption && selectedDepartmentId != nil {
                        VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                            Text("职位")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.primary)
                            
                            if isLoadingPositions {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, Dimens.smallMargin)
                                    Spacer()
                                }
                            } else {
                                Picker("选择职位", selection: $selectedPositionId) {
                                    Text("请选择职位").tag(nil as String?)
                                    ForEach(positions) { pos in
                                        Text(pos.positionName).tag(pos.id as String?)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Dimens.middleMargin)
                                .frame(height: Dimens.inputHeight)
                                .background(Colors.pageBackgroundColor)
                                .cornerRadius(Dimens.inputHeight / 2)
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                    }
                    
                    // 按钮区域
                    HStack(spacing: Dimens.middleMargin) {
                        // 取消按钮
                        Button(action: {
                            showAddDialog = false
                            resetDialogState()
                        }) {
                            Text("取消")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.grayColor)
                                .frame(height: Dimens.btnHeight)
                                .frame(maxWidth: .infinity)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                        .stroke(Colors.grayColor, lineWidth: 1)
                                )
                        }
                        
                        // 确定按钮
                        Button(action: {
                            let role = showRoleOption ? (Int(selectedRole) ?? 0) : 0
                            addUserToCompany(user: user, role: role, positionId: selectedPositionId)
                        }) {
                            Text("确定")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.white)
                                .frame(height: Dimens.btnHeight)
                                .frame(maxWidth: .infinity)
                                .background(isFormValid ? Colors.primaryColor : Colors.grayColor)
                                .cornerRadius(Dimens.btnHeight / 2)
                        }
                        .disabled(!isFormValid)
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.bottom, Dimens.middleMargin)
                }
                .frame(width: UIScreen.main.bounds.width - Dimens.largeMargin * 4)
                .background(Colors.whiteColor)
                .cornerRadius(Dimens.borderRadius)
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
    
    // MARK: - 辅助方法
    
    /// 重置对话框状态
    private func resetDialogState() {
        selectedRole = "0"
        selectedDepartmentId = nil
        selectedPositionId = nil
        departments = []
        positions = []
    }
    
    /// 加载已添加的用户列表
    private func loadAddedUsers() {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { return }
        
        HTTPClient.shared.getCompanyUsers(
            companyId: companyId,
            pageNum: 1,
            pageSize: 1000
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (users, _)):
                    let userIds = users.compactMap { $0.id }
                    self.addedUserIds = Set(userIds)
                case .failure(let error):
                    print("❌ 获取已添加用户列表失败: \(error.localizedDescription)")
                }
            }
        }
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
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        guard !searchText.isEmpty else { return }
        
        if reset {
            isSearchLoading = true
            currentPage = 1
            searchResults = []
        }
        
        HTTPClient.shared.searchUsers(
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
    
    // MARK: - 部门/职位加载方法
    
    /// 加载部门列表
    private func loadDepartments() {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else { return }
        
        isLoadingDepartments = true
        HTTPClient.shared.getDepartments(companyId: companyId) { result in
            DispatchQueue.main.async {
                self.isLoadingDepartments = false
                switch result {
                case .success(let depts):
                    self.departments = depts
                case .failure(let error):
                    print("❌ 获取部门列表失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 加载职位列表
    private func loadPositions(departmentId: String) {
        isLoadingPositions = true
        HTTPClient.shared.getPositions(departmentId: departmentId) { result in
            DispatchQueue.main.async {
                self.isLoadingPositions = false
                switch result {
                case .success(let posList):
                    self.positions = posList
                case .failure(let error):
                    print("❌ 获取职位列表失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 添加用户
    
    /// 添加用户到公司
    private func addUserToCompany(user: SearchUserResult, role: Int, positionId: String?) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId(),
              let userId = user.id else { return }
        
        // 普通管理员只能添加普通用户（role = 0）
        let finalRole: Int
        if isNormalAdmin {
            finalRole = 0
        } else {
            finalRole = role
        }
        
        HTTPClient.shared.addCompanyUser(
            companyId: companyId,
            userId: userId,
            role: finalRole,
            positionId: positionId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if data > 0 {
                        self.alertMessage = "添加成功"
                        self.showAlert = true
                        // 标记为已添加
                        if let userId = user.id {
                            self.addedUserIds.insert(userId)
                        }
                        // 更新搜索结果中的状态
                        self.performSearch(reset: true)
                        self.showAddDialog = false
                        self.resetDialogState()
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

// MARK: - 添加用户行组件

/// 添加用户行视图
struct AddUserRow: View {
    let user: SearchUserResult
    let isAdded: Bool
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
            
            // 添加按钮 / 已添加标签
            if isAdded {
                Text("已添加")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.smallMargin)
                    .background(Colors.grayColor.opacity(0.2))
                    .cornerRadius(Dimens.borderRadius * 2)
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
    AddCompanyUserPage()
}