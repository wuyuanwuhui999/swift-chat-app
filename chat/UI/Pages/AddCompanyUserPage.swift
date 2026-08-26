//
//  AddCompanyUserPage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import SwiftUI

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
    /// 每页条数：固定 20 条，往上滚动到列表底部时加载下一页
    private let pageSize = 20
    @State private var hasMoreData = true
    @State private var isLoadingMore = false
    
    // 已添加的用户ID集合
    @State private var addedUserIds: Set<String> = []
    // 正在添加的用户ID集合（用于显示加载状态）
    @State private var addingUserIds: Set<String> = []
    
    // 添加对话框相关状态
    @State private var showAddDialog = false
    @State private var selectedUser: SearchUserResult?
    @State private var selectedRole = 0  // 0: 普通用户, 1: 管理员
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
    
    /// 表单是否有效（选择了部门和职位，超级管理员还需选择角色）
    private var isFormValid: Bool {
        // 必须选择部门和职位
        guard selectedDepartmentId != nil && selectedPositionId != nil else {
            return false
        }
        // 如果是超级管理员，还需要选择角色（默认已选0）
        return true
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
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            // 标题
            Text("添加用户")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
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
                .fill(Colors.grayColor)
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
            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, user in
                UserSearchRow(
                    user: user,
                    isAdded: isUserAdded(user),
                    isAdding: isUserAdding(user),
                    onAdd: {
                        selectedUser = user
                        // 加载部门和职位数据，然后显示对话框
                        loadDepartmentsAndPositions()
                        showAddDialog = true
                    }
                )
                
                if index < searchResults.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器：往上滚动到底部时自动加载下一页（每页 20 条）
            if hasMoreData && !searchText.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, Dimens.middleMargin)
                .onAppear {
                    loadMoreUsers()
                }
            }
        }
    }
    
    /// 添加用户对话框 - 选择部门和职位
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
                    Text("选择部门和职位")
                        .font(.system(size: Dimens.middleFont))
                        .foregroundColor(.black)
                        .padding(.top, Dimens.middleMargin)
                    
                    // 用户名
                    Text("用户：\(user.username)")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.grayColor)
                        .padding(.horizontal, Dimens.middleMargin)
                    
                    // 角色选项（仅超级管理员显示）
                    if showRoleOption {
                        VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                            Text("角色")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.black)
                            
                            HStack(spacing: Dimens.middleMargin) {
                                Button(action: {
                                    selectedRole = 0
                                }) {
                                    HStack(spacing: Dimens.smallIcon) {
                                        Image(systemName: selectedRole == 0 ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(selectedRole == 0 ? Colors.primaryColor : Colors.grayColor)
                                        Text("普通用户")
                                            .font(.system(size: Dimens.normalFont))
                                            .foregroundColor(.black)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    selectedRole = 1
                                }) {
                                    HStack(spacing: Dimens.smallIcon) {
                                        Image(systemName: selectedRole == 1 ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(selectedRole == 1 ? Colors.primaryColor : Colors.grayColor)
                                        Text("管理员")
                                            .font(.system(size: Dimens.normalFont))
                                            .foregroundColor(.black)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                    }
                    
                    // 部门选择
                    VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                        Text("部门")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)
                        
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
                    
                    // 职位选择
                    VStack(alignment: .leading, spacing: Dimens.smallMargin) {
                        Text("职位")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)
                        
                        if isLoadingPositions {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, Dimens.smallMargin)
                                Spacer()
                            }
                        } else if selectedDepartmentId != nil {
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
                        } else {
                            Text("请先选择部门")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.grayColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Dimens.smallMargin)
                        }
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    
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
                            // 非超级管理员不显示角色选项，统一按普通用户（0）提交
                            let role = showRoleOption ? selectedRole : 0
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
    
    /// 判断用户是否已在公司
    /// 两个来源：onAppear 拉取的公司成员集合 addedUserIds、后端搜索接口返回的 checked 标记
    /// - Parameter user: 搜索结果用户
    /// - Returns: 已在公司返回 true（行内展示灰色「已添加」）
    private func isUserAdded(_ user: SearchUserResult) -> Bool {
        if let userId = user.id, addedUserIds.contains(userId) {
            return true
        }
        return user.isAdded
    }
    
    /// 判断用户是否正在添加中（id 为空时恒为 false，避免多条空 id 的行互相串状态）
    /// - Parameter user: 搜索结果用户
    /// - Returns: 正在添加返回 true（行内展示 ProgressView）
    private func isUserAdding(_ user: SearchUserResult) -> Bool {
        guard let userId = user.id else { return false }
        return addingUserIds.contains(userId)
    }
    
    /// 重置对话框状态
    private func resetDialogState() {
        selectedRole = 0
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
    /// - Parameters:
    ///   - reset: true 表示重新搜索（回到第 1 页并清空列表），false 表示追加下一页
    ///   - completion: 请求结束（无论成功失败）后的回调，供下拉刷新等待真实结果
    private func performSearch(reset: Bool = true, completion: (() -> Void)? = nil) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            completion?()
            return
        }
        
        guard !searchText.isEmpty else {
            completion?()
            return
        }
        
        if reset {
            isSearchLoading = true
            currentPage = 1
            searchResults = []
        }
        
        // 记录本次请求的页码，失败时用于回滚
        let requestPage = currentPage
        
        HTTPClient.shared.searchCompanyUsers(
            keyword: searchText,
            companyId: companyId,
            pageNum: requestPage,
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
                    // 是否还有下一页：total 有效时按 total 判断；total 缺失（兜底 0）时按本页是否满页判断
                    if total > 0 {
                        self.hasMoreData = self.searchResults.count < total
                    } else {
                        self.hasMoreData = users.count >= self.pageSize
                    }
                    print("✅ 搜索用户成功，共 \(users.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 搜索用户失败: \(error.localizedDescription)")
                    if reset {
                        self.searchResults = []
                    } else {
                        // 加载下一页失败：页码回滚，避免下次触发时跳页丢数据
                        self.currentPage = max(1, requestPage - 1)
                    }
                    // 请求失败必须提示，避免与「未找到相关用户」空态混淆
                    self.presentAlert("搜索用户失败：\(error.localizedDescription)")
                }
                
                completion?()
            }
        }
    }
    
    /// 加载更多用户（往上滚动到列表底部时触发，每页 20 条）
    private func loadMoreUsers() {
        guard !isLoadingMore, !isRefreshing, hasMoreData, !searchText.isEmpty else { return }
        isLoadingMore = true
        currentPage += 1
        performSearch(reset: false)
    }
    
    /// 下拉刷新（等搜索请求真正返回后再收起刷新指示器）
    @MainActor
    private func refreshData() async {
        isRefreshing = true
        
        if !searchText.isEmpty {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                performSearch(reset: true) {
                    continuation.resume()
                }
            }
        }
        
        isRefreshing = false
    }
    
    // MARK: - 部门/职位加载方法
    
    /// 加载部门和职位数据（先加载部门，部门加载完成后自动加载职位）
    private func loadDepartmentsAndPositions() {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        // 重置部门相关状态
        departments = []
        positions = []
        selectedDepartmentId = nil
        selectedPositionId = nil
        
        isLoadingDepartments = true
        HTTPClient.shared.getDepartments(companyId: companyId) { result in
            DispatchQueue.main.async {
                self.isLoadingDepartments = false
                switch result {
                case .success(let depts):
                    self.departments = depts
                    print("✅ 获取部门列表成功，共 \(depts.count) 个部门")
                case .failure(let error):
                    print("❌ 获取部门列表失败: \(error.localizedDescription)")
                    self.presentAlert("获取部门列表失败")
                }
            }
        }
    }
    
    /// 加载职位列表
    private func loadPositions(departmentId: String) {
        isLoadingPositions = true
        // 清空之前的职位列表
        positions = []
        selectedPositionId = nil
        
        HTTPClient.shared.getPositions(departmentId: departmentId) { result in
            DispatchQueue.main.async {
                self.isLoadingPositions = false
                switch result {
                case .success(let posList):
                    self.positions = posList
                    print("✅ 获取职位列表成功，共 \(posList.count) 个职位")
                case .failure(let error):
                    print("❌ 获取职位列表失败: \(error.localizedDescription)")
                    self.presentAlert("获取职位列表失败")
                }
            }
        }
    }
    
    // MARK: - 添加用户
    
    /// 添加用户到公司
    private func addUserToCompany(user: SearchUserResult, role: Int, positionId: String?) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId(),
              let userId = user.id else {
            presentAlert("缺少必要参数")
            return
        }
        
        // 普通管理员只能添加普通用户（role = 0）
        let finalRole: Int
        if isNormalAdmin {
            finalRole = 0
        } else {
            finalRole = role
        }
        
        // 标记为正在添加
        addingUserIds.insert(userId)
        
        // 关闭对话框
        showAddDialog = false
        resetDialogState()
        
        HTTPClient.shared.addCompanyUser(
            companyId: companyId,
            userId: userId,
            role: finalRole,
            positionId: positionId
        ) { result in
            DispatchQueue.main.async {
                // 移除正在添加标记
                self.addingUserIds.remove(userId)
                
                switch result {
                case .success(let data):
                    if data > 0 {
                        self.presentAlert("添加成功")
                        // 标记为已添加
                        self.addedUserIds.insert(userId)
                        // 更新搜索结果中的状态
                        self.performSearch(reset: true)
                    } else {
                        self.presentAlert("添加失败，请稍后重试")
                    }
                case .failure(let error):
                    self.presentAlert(error.localizedDescription)
                }
            }
        }
    }
    
    /// 显示提示框
    /// - Parameter message: 提示文案
    private func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 添加用户行组件（已抽为公共组件 UI/Components/UserSearchRow.swift）

#Preview {
    AddCompanyUserPage()
}