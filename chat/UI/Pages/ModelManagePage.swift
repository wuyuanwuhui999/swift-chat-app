//
//  ModelManagePage.swift
//  chat
//
//  Created by 吴文强 on 2026/7/7.
//

import SwiftUI

/// 模型管理页面
struct ModelManagePage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // 模型列表相关状态
    @State private var models: [ChatModel] = []
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
    
    // 通用
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showAddModelPage = false
    
    // 当前滑动打开的条目ID
    @State private var activeSwipeModelId: String?
    
    // 跳转到更新页面
    @State private var selectedModel: ChatModel?
    @State private var showUpdateModelPage = false
    
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
                        // 模型列表卡片
                        modelListCardView
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
            .navigationDestination(isPresented: $showAddModelPage) {
                AddModelPage(onModelAdded: {
                    loadModelList(reset: true)
                })
                .navigationBarHidden(true)
            }
            .navigationDestination(isPresented: $showUpdateModelPage) {
                if let model = selectedModel {
                    UpdateModelPage(
                        model: model,
                        onModelUpdated: {
                            loadModelList(reset: true)
                        }
                    )
                    .navigationBarHidden(true)
                }
            }
        }
        .onAppear {
            loadModelList()
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - 视图组件
    
    /// 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            Text("模型管理")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: {
                showAddModelPage = true
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
                
                TextField("搜索模型", text: $searchText)
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
    
    /// 模型列表卡片视图
    @ViewBuilder
    private var modelListCardView: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .padding(.vertical, Dimens.largeMargin)
            } else if models.isEmpty {
                emptyStateView
            } else {
                modelListView
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 模型列表视图
    @ViewBuilder
    private var modelListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                SwipeableModelRow(
                    model: model,
                    isActiveSwipe: activeSwipeModelId == model.id,
                    onSwipeStateChanged: { modelId, isOpen in
                        if isOpen {
                            if let currentActive = activeSwipeModelId, currentActive != modelId {
                                activeSwipeModelId = nil
                            }
                            activeSwipeModelId = modelId
                        } else {
                            if activeSwipeModelId == modelId {
                                activeSwipeModelId = nil
                            }
                        }
                    },
                    onUse: {
                        useModel(model)
                    },
                    onEdit: {
                        showUpdateModel(model)
                    },
                    onDelete: {
                        deleteModel(model)
                    }
                )
                
                if index < models.count - 1 {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
            
            if hasMoreData && !isLoadingMore && !isRefreshing {
                ProgressView()
                    .padding(.vertical, Dimens.middleMargin)
                    .onAppear {
                        loadMoreModels()
                    }
            }
        }
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "cpu")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text(isSearching ? "未找到相关模型" : "暂无模型")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
            
            if !isSearching {
                Text("点击右上角「+」添加模型")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    // MARK: - 数据加载方法
    
    /// 加载模型列表
    private func loadModelList(reset: Bool = true) {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            print("❌ 未找到公司ID")
            return
        }
        
        if reset {
            isLoading = true
            currentPage = 1
            models = []
            hasMoreData = true
            activeSwipeModelId = nil
        }
        
        let keyword = isSearching ? searchText : ""
        
        HTTPClient.shared.getModelList(
            companyId: companyId,
            keyword: keyword
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isLoadingMore = false
                
                switch result {
                case .success(let (modelList, total)):
                    if reset {
                        self.models = modelList
                    } else {
                        let existingIds = Set(self.models.map { $0.id })
                        let newModels = modelList.filter { !existingIds.contains($0.id) }
                        self.models.append(contentsOf: newModels)
                    }
                    self.hasMoreData = self.models.count < total
                    print("✅ 获取模型列表成功，共 \(modelList.count) 条，总计 \(total) 条")
                    
                case .failure(let error):
                    print("❌ 获取模型列表失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    /// 加载更多模型
    private func loadMoreModels() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true
        currentPage += 1
        loadModelList(reset: false)
    }
    
    /// 下拉刷新
    private func refreshData() async {
        await MainActor.run {
            isRefreshing = true
            activeSwipeModelId = nil
        }
        
        loadModelList(reset: true)
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    /// 处理搜索文本变化（防抖）
    private func handleSearchTextChange(_ newValue: String) {
        searchWorkItem?.cancel()
        
        if newValue.isEmpty {
            isSearching = false
            loadModelList(reset: true)
            return
        }
        
        isSearching = true
        
        let workItem = DispatchWorkItem {
            self.loadModelList(reset: true)
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // MARK: - 模型操作
    
    /// 使用模型
    private func useModel(_ model: ChatModel) {
        appState.saveCurrentModel(model)
        
        alertMessage = "已切换模型"
        showAlert = true
        print("✅ 已切换模型: \(model.modelName)")
    }
    
    /// 显示更新模型页面
    private func showUpdateModel(_ model: ChatModel) {
        selectedModel = model
        showUpdateModelPage = true
    }
    
    /// 删除模型
    private func deleteModel(_ model: ChatModel) {
        if appState.currentModel?.id == model.id {
            alertMessage = "当前使用中的模型不能删除"
            showAlert = true
            return
        }
        
        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除模型 \"\(model.modelName)\" 吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            performDeleteModel(model)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 执行删除模型
    private func performDeleteModel(_ model: ChatModel) {
        HTTPClient.shared.deleteModel(modelId: model.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedCount):
                    if deletedCount > 0 {
                        self.alertMessage = "删除成功"
                        self.showAlert = true
                        self.models.removeAll { $0.id == model.id }
                        if self.appState.currentModel?.id == model.id {
                            self.appState.currentModel = nil
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

// MARK: - 可滑动模型行组件

/// 可滑动模型行视图
struct SwipeableModelRow: View {
    let model: ChatModel
    let isActiveSwipe: Bool
    let onSwipeStateChanged: (String, Bool) -> Void
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var appState = AppState.shared
    
    @State private var offset: CGFloat = 0
    
    private var actionButtonsWidth: CGFloat {
        return 80 + 70 + 70
    }
    
    private var isCurrentModel: Bool {
        return appState.currentModel?.id == model.id
    }
    
    var body: some View {
        let rowHeight: CGFloat = Dimens.middleAvater + Dimens.middleMargin * 2
        
        ZStack {
            // 背景层（滑动时显示的操作按钮）
            HStack(spacing: 0) {
                Spacer()
                
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        resetOffset()
                    }
                    onUse()
                }) {
                    Text(isCurrentModel ? "已使用" : "使用")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .frame(maxHeight: .infinity)
                        .background(isCurrentModel ? Colors.grayColor : Colors.primaryColor)
                }
                .disabled(isCurrentModel)
                
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
            
            // 前景层
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                Text(model.modelName)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                HStack {
                    Text(model.type)
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                        .padding(.horizontal, Dimens.smallIcon)
                        .padding(.vertical, 4)
                        .background(Colors.grayColor.opacity(0.2))
                        .cornerRadius(Dimens.smallIcon)
                    
                    if isCurrentModel {
                        Text("当前使用中")
                            .font(.system(size: Dimens.normalFont - 4))
                            .foregroundColor(Colors.primaryColor)
                            .padding(.horizontal, Dimens.smallIcon)
                            .padding(.vertical, 4)
                            .background(Colors.primaryColor.opacity(0.1))
                            .cornerRadius(Dimens.smallIcon)
                    }
                }
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
                            onSwipeStateChanged(model.id, true)
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
    
    private func resetOffset() {
        offset = 0
        onSwipeStateChanged(model.id, false)
    }
}

#Preview {
    ModelManagePage()
}
