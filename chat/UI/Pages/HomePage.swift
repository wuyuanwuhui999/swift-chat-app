import SwiftUI

/// 主页面 - 聊天界面
struct HomePage: View {
    @ObservedObject private var appState = AppState.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputMessage = ""
    @State private var showTenantList = false
    @State private var showModelList = false
    @State private var showMenu = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // 背景
            backgroundView
            
            VStack(spacing: 0) {
                // 标题栏
                headerView
                
                // 聊天消息区域
                chatMessagesView
                
                // 底部输入栏
                inputBarView
            }
        }
        .onAppear {
            loadTenantAndModel()
        }
        .overlay(tenantListOverlay)
        .overlay(modelListOverlay)
        .overlay(loadingOverlay)
        .actionSheet(isPresented: $showMenu) {
            menuActionSheet
        }
    }
    
    // MARK: - 视图组件
    
    /// 背景视图
    private var backgroundView: some View {
        Colors.pageBackgroundColor
            .ignoresSafeArea()
    }
    
    /// 标题栏视图
    private var headerView: some View {
        ChatHeader(
            showTenantList: $showTenantList,
            showModelList: $showModelList,
            onMenuClick: { showMenu.toggle() }
        )
    }
    
    /// 聊天消息区域视图
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(.vertical, Dimens.middleMargin)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    /// 底部输入栏视图
    private var inputBarView: some View {
        MessageInputBar(
            messageText: $inputMessage,
            onSend: sendMessage
        )
    }
    
    /// 租户列表弹窗覆盖层
    @ViewBuilder
    private var tenantListOverlay: some View {
        if showTenantList {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showTenantList = false
                }
            
            TenantListPopup(isPresented: $showTenantList) { tenant in
                appState.saveCurrentTenant(tenant)
                showTenantList = false
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
    }
    
    /// 模型列表弹窗覆盖层
    @ViewBuilder
    private var modelListOverlay: some View {
        if showModelList {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showModelList = false
                }
            
            ModelListPopup(isPresented: $showModelList) { model in
                appState.saveCurrentModel(model)
                showModelList = false
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
    }
    
    /// 加载指示器覆盖层
    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
        }
    }
    
    /// 菜单选项
    private var menuActionSheet: ActionSheet {
        ActionSheet(
            title: Text("菜单"),
            buttons: [
                .default(Text("上传文档")) { /* 后续实现 */ },
                .default(Text("我的文档")) { /* 后续实现 */ },
                .default(Text("会话记录")) { /* 后续实现 */ },
                .default(Text("设置提示词")) { /* 后续实现 */ },
                .default(Text("我的收藏提示词")) { /* 后续实现 */ },
                .cancel(Text("取消"))
            ]
        )
    }
    
    // MARK: - 辅助方法
    
    /// 滚动到底部
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    /// 发送消息
    private func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: inputMessage, isUser: true)
        messages.append(userMessage)
        
        let sentMessage = inputMessage
        inputMessage = ""
        
        // TODO: 调用AI接口获取回复
        // 这里先模拟AI回复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiMessage = ChatMessage(content: "收到消息：\(sentMessage)", isUser: false)
            messages.append(aiMessage)
        }
    }
    
    /// 加载租户列表和模型列表
    private func loadTenantAndModel() {
        isLoading = true
        
        let group = DispatchGroup()
        
        // 获取租户列表
        group.enter()
        HTTPClient.shared.getUserTenantList { result in
            DispatchQueue.main.async {
                handleTenantListResult(result)
                group.leave()
            }
        }
        
        // 获取模型列表
        group.enter()
        HTTPClient.shared.getModelList { result in
            DispatchQueue.main.async {
                handleModelListResult(result)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
    
    /// 处理租户列表结果
    private func handleTenantListResult(_ result: Result<[Tenant], NetworkError>) {
        switch result {
        case .success(let tenants):
            appState.tenantList = tenants
            handleCurrentTenant(tenants)
        case .failure(let error):
            print("❌ 获取租户列表失败: \(error.localizedDescription)")
        }
    }
    
    /// 处理当前租户
    private func handleCurrentTenant(_ tenants: [Tenant]) {
        let cachedTenantId = appState.getCachedTenantId()
        if let tenantId = cachedTenantId,
           let matchedTenant = tenants.first(where: { $0.id == tenantId }) {
            // 缓存中有且匹配成功
            appState.currentTenant = matchedTenant
        } else if let firstTenant = tenants.first {
            // 缓存中没有或匹配失败，取第一条
            appState.saveCurrentTenant(firstTenant)
        }
    }
    
    /// 处理模型列表结果
    private func handleModelListResult(_ result: Result<[ChatModel], NetworkError>) {
        switch result {
        case .success(let models):
            appState.modelList = models
            handleCurrentModel(models)
        case .failure(let error):
            print("❌ 获取模型列表失败: \(error.localizedDescription)")
        }
    }
    
    /// 处理当前模型
    private func handleCurrentModel(_ models: [ChatModel]) {
        let cachedModelId = appState.getCachedModelId()
        if let modelId = cachedModelId,
           let matchedModel = models.first(where: { $0.id == modelId }) {
            // 缓存中有且匹配成功
            appState.currentModel = matchedModel
        } else if let firstModel = models.first {
            // 缓存中没有或匹配失败，取第一条
            appState.saveCurrentModel(firstModel)
        }
    }
}

#Preview {
    HomePage()
}
