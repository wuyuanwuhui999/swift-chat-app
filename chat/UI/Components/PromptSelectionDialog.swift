// chat/chat/UI/Components/PromptSelectionDialog.swift
//
//  PromptSelectionDialog.swift
//  chat
//
//  Created by 吴文强 on 2026/9/9.
//

import SwiftUI

/// 提示词选择对话框组件
struct PromptSelectionDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    
    // 提示词列表相关状态
    @State private var prompts: [Prompt] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var pageSize = 20
    @State private var hasMoreData = true
    
    // 搜索相关
    @State private var searchText = ""
    @State private var searchWorkItem: DispatchWorkItem?
    @State private var isSearching = false
    
    // 选中状态 - 当前选中的提示词ID（用于UI高亮和确定按钮）
    @State private var selectedPromptId: String?
    
    // 当前滑动打开的条目ID
    @State private var activeSwipePromptId: String?
    
    // 删除确认
    @State private var showDeleteAlert = false
    @State private var promptToDelete: Prompt?
    
    // 跳转到提示词管理页面
    @State private var showPromptManage = false
    
    // 提示
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 回调：确定时返回选中的提示词ID，取消时返回nil
    let onConfirm: (String?) -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 半透明遮罩层
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel?()
                        isPresented = false
                    }
                
                // 对话框内容 - 从底部弹出
                VStack(spacing: 0) {
                    // 标题栏
                    headerView
                    
                    // 可滚动的内容区域 - 灰色背景
                    ScrollView {
                        VStack(spacing: Dimens.middleMargin) {
                            // 搜索框
                            searchBarView
                            
                            // 提示词列表卡片
                            promptListCardView
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.middleMargin)
                    }
                    .background(Colors.pageBackgroundColor)
                    
                    // 底部操作区域
                    bottomActionView
                }
                .frame(
                    width: geometry.size.width,
                    height: min(geometry.size.height * 0.8, geometry.size.height - 100)
                )
                .background(Colors.whiteColor)
                .clipShape(RoundedCorner(radius: Dimens.borderRadius, corners: [.topLeft, .topRight]))
                .position(x: geometry.size.width / 2, y: geometry.size.height - (min(geometry.size.height * 0.8, geometry.size.height - 100) / 2))
            }
        }
        .onAppear {
            loadPrompts()
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                if let prompt = promptToDelete {
                    deletePrompt(prompt)
                }
            }
        } message: {
            Text("确定要删除该提示词吗？")
        }
        .fullScreenCover(isPresented: $showPromptManage) {
            NavigationView {
                PromptManagePage()
                    .navigationBarHidden(true)
            }
        }
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        HStack {
            Text("提示词")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
            // 加号图标 - 跳转到提示词管理页面
            Button(action: {
                showPromptManage = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.primaryColor)
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
    }
    
    /// 提示词列表卡片视图
    @ViewBuilder
    private var promptListCardView: some View {
        VStack(spacing: 0) {
            if isLoading && prompts.isEmpty {
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
                SwipeablePromptSelectionRow(
                    prompt: prompt,
                    isSelected: selectedPromptId == prompt.id,
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
                        // 点击使用/取消使用
                        if selectedPromptId == prompt.id {
                            // 取消使用
                            selectedPromptId = nil
                        } else {
                            selectedPromptId = prompt.id
                        }
                    },
                    onEdit: {
                        // 编辑跳转到PromptManagePage
                        showPromptManage = true
                    },
                    onDelete: {
                        promptToDelete = prompt
                        showDeleteAlert = true
                    }
                )
                
                if index < prompts.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            // 加载更多指示器
            if hasMoreData && !isLoadingMore && !isLoading {
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
    
    /// 底部操作区域视图
    @ViewBuilder
    private var bottomActionView: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 取消按钮
            Button(action: {
                onCancel?()
                isPresented = false
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
                // 确定时传递选中的提示词ID
                onConfirm(selectedPromptId)
                isPresented = false
            }) {
                Text("确定")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.white)
                    .frame(height: Dimens.btnHeight)
                    .frame(maxWidth: .infinity)
                    .background(selectedPromptId != nil ? Colors.primaryColor : Colors.grayColor)
                    .cornerRadius(Dimens.btnHeight / 2)
            }
            .disabled(selectedPromptId == nil)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - 数据加载方法
    
    /// 加载提示词列表
    private func loadPrompts(reset: Bool = true) {
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
        
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
                }
            }
        }
    }
    
    /// 加载更多提示词
    private func loadMorePrompts() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true
        currentPage += 1
        loadPrompts(reset: false)
    }
    
    /// 处理搜索文本变化（防抖）
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            isSearching = false
            loadPrompts(reset: true)
            return
        }
        
        isSearching = true
        
        let workItem = DispatchWorkItem {
            self.loadPrompts(reset: true)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // MARK: - 删除提示词
    
    /// 删除提示词
    private func deletePrompt(_ prompt: Prompt) {
        guard let tenantId = appState.currentTenant?.id else {
            showAlertMessage("未找到租户ID")
            return
        }
        
        HTTPClient.shared.deletePrompt(promptId: prompt.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedCount):
                    if deletedCount > 0 {
                        // 从列表中移除
                        self.prompts.removeAll { $0.id == prompt.id }
                        // 如果删除的是当前选中的提示词，清除选中状态
                        if self.selectedPromptId == prompt.id {
                            self.selectedPromptId = nil
                        }
                        showAlertMessage("删除成功")
                    } else {
                        showAlertMessage("删除失败")
                    }
                case .failure(let error):
                    showAlertMessage(error.localizedDescription)
                }
            }
        }
    }
    
    /// 显示提示消息
    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 可滑动提示词行组件（用于选择对话框）

/// 可滑动提示词行视图（选择对话框专用）
struct SwipeablePromptSelectionRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let isActiveSwipe: Bool
    let onSwipeStateChanged: (String, Bool) -> Void
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    // 滑动偏移量
    @State private var offset: CGFloat = 0
    
    // 计算滑动操作区域的宽度
    private var actionButtonsWidth: CGFloat {
        return 80 + 70 + 70  // 使用 + 编辑 + 删除
    }
    
    var body: some View {
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
                    Text(isSelected ? "取消使用" : "使用")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(isSelected ? Colors.grayColor : Colors.primaryColor)
                }
                
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
            .frame(maxWidth: .infinity)
            
            // 前景层（可滑动的提示词卡片）
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                // 提示词内容 - 最多显示三行
                Text(prompt.prompt)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(isSelected ? Colors.primaryColor : .black)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity)
            .background(Colors.whiteColor)
            .offset(x: offset)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        let newOffset = value.translation.width
                        
                        if newOffset < 0 {
                            let maxOffset = -actionButtonsWidth
                            offset = max(newOffset, maxOffset)
                        } else if newOffset > 0 && offset < 0 {
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
        .frame(height: rowHeight)
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
    PromptSelectionDialog(
        isPresented: .constant(true),
        onConfirm: { _ in },
        onCancel: { }
    )
}