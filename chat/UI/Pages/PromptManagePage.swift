//
//  PromptManagePage.swift
//  chat
//
//  Created by 吴文强 on 2026/7/3.
//

import SwiftUI

/// 提示词管理页面
struct PromptManagePage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 提示词列表
    @State private var prompts: [Prompt] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var pageSize = 20
    @State private var hasMoreData = true
    
    // 搜索相关
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // 下拉刷新
    @State private var isRefreshing = false
    
    // 编辑弹窗
    @State private var showEditDialog = false
    @State private var editingPrompt: Prompt?
    @State private var editPromptText = ""
    
    // 通用
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showAddPromptPage = false
    
    // 当前滑动打开的条目ID
    @State private var activeSwipePromptId: String?
    
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
                        // 提示词列表卡片
                        promptListCardView
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
            // 添加提示词页面跳转
            .navigationDestination(isPresented: $showAddPromptPage) {
                AddPromptPage()
                    .navigationBarHidden(true)
            }
            // 编辑弹窗覆盖层
            .overlay(editPromptDialog)
        }
        .onAppear {
            loadPromptList()
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
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            // 标题
            Text("提示词管理")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
            // 加号按钮 - 跳转到添加提示词页面
            Button(action: {
                showAddPromptPage = true
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
    
    /// 搜索框视图
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Colors.grayColor)
                    .font(.system(size: Dimens.smallIcon))
                
                TextField("搜索提示词", text: $searchText)
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
    
    /// 提示词列表卡片视图
    @ViewBuilder
    private var promptListCardView: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if prompts.isEmpty {
                emptyStateView
            } else {
                promptListView
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 提示词列表视图
    @ViewBuilder
    private var promptListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                SwipeablePromptRow(
                    prompt: prompt,
                    isActiveSwipe: activeSwipePromptId == prompt.id,
                    onSwipeStateChanged: { promptId, isOpen in
                        if isOpen {
                            if let currentActive = activeSwipePromptId, currentActive != promptId {
                                activeSwipePromptId = nil
                            }
                            activeSwipePromptId = promptId
                        } else {
                            if activeSwipePromptId == promptId {
                                activeSwipePromptId = nil
                            }
                        }
                    },
                    onUse: {
                        usePrompt(prompt)
                    },
                    onEdit: {
                        showEditPrompt(prompt)
                    },
                    onDelete: {
                        deletePrompt(prompt)
                    }
                )
                
                if index < prompts.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器
            if hasMoreData && !isLoadingMore && !isRefreshing {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMorePrompts()
                    }
            }
        }
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "text.quote")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text(isSearching ? "未找到相关提示词" : "暂无提示词")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
            
            if !isSearching {
                Text("点击右上角「+」添加提示词")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    // MARK: - 编辑弹窗
    
    /// 编辑提示词弹窗
    @ViewBuilder
    private var editPromptDialog: some View {
        if showEditDialog, let prompt = editingPrompt {
            CustomDialog(
                isPresented: $showEditDialog,
                title: "编辑提示词",
                content: {
                    // 提示词编辑框
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $editPromptText)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)
                            .frame(minHeight: 200, maxHeight: .infinity)
                            .padding(.horizontal, Dimens.middleMargin)
                            .padding(.vertical, Dimens.middleMargin)
                            .cornerRadius(Dimens.borderRadius)
                            .scrollContentBackground(.hidden)
                            .background(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.borderRadius)
                                    .stroke(Colors.grayColor, lineWidth: 1)
                            )
                        
                        // 占位文字
                        if editPromptText.isEmpty {
                            Text("请输入提示词内容...")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.grayColor)
                                .padding(.horizontal, Dimens.middleMargin + 5)
                                .padding(.vertical, Dimens.middleMargin + 8)
                                .allowsHitTesting(false)
                        }
                    }
                },
                onConfirm: {
                    handleUpdatePrompt()
                },
                onCancel: {
                    showEditDialog = false
                    editingPrompt = nil
                    editPromptText = ""
                }
            )
        }
    }
    
    // MARK: - 数据加载方法
    
    /// 加载提示词列表
    private func loadPromptList(reset: Bool = true) {
        guard let tenantId = appState.currentTenant?.id else {
            print("❌ 未找到租户ID")
            return
        }
        
        if reset {
            isLoading = true
            currentPage = 1
            prompts = []
            hasMoreData = true
            activeSwipePromptId = nil
        }
        
        // 构建请求参数
        let keyword = isSearching ? searchText : ""
        
        HTTPClient.shared.getPromptList(
            tenantId: tenantId,
            keyword: keyword,
            pageNum: currentPage,
            pageSize: pageSize
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let (promptList, total)):
                    if reset {
                        self.prompts = promptList
                    } else {
                        // 去重添加
                        let existingIds = Set(self.prompts.map { $0.id })
                        let newPrompts = promptList.filter { !existingIds.contains($0.id) }
                        self.prompts.append(contentsOf: newPrompts)
                    }
                    self.hasMoreData = self.prompts.count < total
                    print("✅ 获取提示词列表成功，共 \(promptList.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 获取提示词列表失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    /// 加载更多提示词
    private func loadMorePrompts() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true
        currentPage += 1
        loadPromptList(reset: false)
    }
    
    /// 下拉刷新
    private func refreshData() async {
        await MainActor.run {
            isRefreshing = true
            activeSwipePromptId = nil
        }
        
        loadPromptList(reset: true)
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    /// 处理搜索文本变化（防抖）
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            isSearching = false
            loadPromptList(reset: true)
            return
        }
        
        isSearching = true
        
        let workItem = DispatchWorkItem {
            self.loadPromptList(reset: true)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // MARK: - 提示词操作
    
    /// 使用提示词
    private func usePrompt(_ prompt: Prompt) {
        // 1. 更新当前提示词到 AppState
        appState.updatePrompt(Prompt(
            id: prompt.id,
            tenantId: prompt.tenantId,
            userId: prompt.userId,
            prompt: prompt.prompt,
            createTime: prompt.createTime,
            updateTime: prompt.updateTime
        ))
        
        // 2. 保存提示词ID到缓存（拼接tenantId）
        if let tenantId = appState.currentTenant?.id {
            appState.saveCurrentPromptId(prompt.id, tenantId: tenantId)
            print("✅ 已保存提示词ID到缓存: promptId=\(prompt.id), tenantId=\(tenantId)")
        } else {
            print("⚠️ 未找到租户ID，无法保存提示词缓存")
        }
        
        // 3. 显示提示
        alertMessage = "已应用提示词"
        showAlert = true
        print("✅ 已应用提示词: \(prompt.prompt.prefix(50))...")
    }
    
    /// 显示编辑提示词弹窗
    private func showEditPrompt(_ prompt: Prompt) {
        editingPrompt = prompt
        editPromptText = prompt.prompt
        showEditDialog = true
    }
    
    /// 更新提示词
    private func handleUpdatePrompt() {
        guard let prompt = editingPrompt else { return }
        
        let trimmedText = editPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            alertMessage = "提示词不能为空"
            showAlert = true
            return
        }
        
        guard let tenantId = appState.currentTenant?.id else {
            alertMessage = "未找到租户ID"
            showAlert = true
            return
        }
        
        HTTPClient.shared.updatePromptById(
            id: prompt.id,
            prompt: trimmedText,
            tenantId: tenantId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let success):
                    if success {
                        self.alertMessage = "更新成功"
                        self.showAlert = true
                        self.showEditDialog = false
                        self.editingPrompt = nil
                        self.editPromptText = ""
                        // 刷新列表
                        self.loadPromptList(reset: true)
                    } else {
                        self.alertMessage = "更新失败"
                        self.showAlert = true
                    }
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    /// 删除提示词
    private func deletePrompt(_ prompt: Prompt) {
        // 显示确认对话框
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除该提示词吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            performDeletePrompt(prompt)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 执行删除提示词
    private func performDeletePrompt(_ prompt: Prompt) {
        HTTPClient.shared.deletePrompt(promptId: prompt.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedCount):
                    if deletedCount > 0 {
                        self.alertMessage = "删除成功"
                        self.showAlert = true
                        // 从列表中移除
                        self.prompts.removeAll { $0.id == prompt.id }
                        // 如果删除的是当前使用的提示词，清空 currentPrompt
                        if self.appState.currentPrompt?.id == prompt.id {
                            self.appState.currentPrompt = nil
                        }
                    } else {
                        self.alertMessage = "删除失败"
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

// MARK: - 可滑动提示词行组件

/// 可滑动提示词行视图
struct SwipeablePromptRow: View {
    let prompt: Prompt
    let isActiveSwipe: Bool
    let onSwipeStateChanged: (String, Bool) -> Void
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var appState = AppState.shared
    
    // 滑动偏移量
    @State private var offset: CGFloat = 0
    
    // 计算滑动操作区域的宽度
    private var actionButtonsWidth: CGFloat {
        var width: CGFloat = 0
        width += 80  // 使用按钮宽度
        width += 70  // 编辑按钮宽度
        width += 70  // 删除按钮宽度
        return width
    }
    
    /// 判断是否为当前使用的提示词
    private var isCurrentPrompt: Bool {
        return appState.currentPrompt?.id == prompt.id
    }
    
    var body: some View {
        // 使用固定高度，确保背景层和前景层高度一致
        let rowHeight: CGFloat = Dimens.middleAvater + Dimens.middleMargin * 2
        
        ZStack {
            // 背景层（滑动时显示的操作按钮）
            HStack(spacing: 0) {
                Spacer()
                
                // 使用按钮
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        resetOffset()
                    }
                    onUse()
                }) {
                    Text(isCurrentPrompt ? "已使用" : "使用")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(isCurrentPrompt ? Colors.grayColor : Colors.primaryColor)
                }
                .disabled(isCurrentPrompt)
                
                // 编辑按钮
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        resetOffset()
                    }
                    onEdit()
                }) {
                    Text("编辑")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                        .background(Colors.subColor)
                }
                
                // 删除按钮
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        resetOffset()
                    }
                    onDelete()
                }) {
                    Text("删除")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                        .background(Colors.warnColor)
                }
            }
            .frame(maxWidth: .infinity)  // ✅ 固定背景层高度
            
            // 前景层（可滑动的提示词卡片）
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                // 提示词内容 - 最多显示两行
                Text(prompt.prompt)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                // 当前使用标签
                if isCurrentPrompt {
                    Text("当前使用中")
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
            .frame(height:rowHeight)
            .frame(maxWidth: .infinity)  // ✅ 固定前景层高度
            .background(Colors.whiteColor)
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        let newOffset = value.translation.width
                        
                        // 只允许向左滑动（负值）
                        if newOffset < 0 {
                            let maxOffset = -actionButtonsWidth
                            offset = max(newOffset, maxOffset)
                        } else if newOffset > 0 && offset < 0 {
                            // 向右滑动恢复
                            offset = min(0, offset + newOffset)
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = actionButtonsWidth / 2
                        
                        if offset < -threshold {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -actionButtonsWidth
                            }
                            onSwipeStateChanged(prompt.id, true)
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                resetOffset()
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        resetOffset()
                    }
                }
            }
        }
        .frame(height: rowHeight)  // ✅ 整体固定高度
        .clipped()
        .onChange(of: isActiveSwipe) { newValue in
            if !newValue && offset < 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    resetOffset()
                }
            }
        }
    }
    
    /// 复位偏移量
    private func resetOffset() {
        offset = 0
        onSwipeStateChanged(prompt.id, false)
    }
}

#Preview {
    PromptManagePage()
}
