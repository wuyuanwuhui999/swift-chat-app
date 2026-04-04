import SwiftUI

/// 主页面 - 聊天界面
struct HomePage: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var webSocketManager = WebSocketManager.shared
    @State private var messages: [ChatMessage] = []
    @State private var inputMessage = ""
    @State private var showTenantList = false
    @State private var showModelList = false
    @State private var showMenu = false
    @State private var isLoading = false
    @State private var showThink = false  // 深度思考开关
    @State private var language = "zh"   // 语言：zh/en
    @State private var currentChatId: String = ""  // 当前聊天ID
    @State private var currentAIResponse = ""  // 当前AI响应（用于流式追加）
    @State private var isReceivingMessage = false  // 是否正在接收消息
    
    // 文档选择相关状态
    @State private var showDocumentQuery = false  // 查询文档按钮激活状态
    @State private var showDocumentPicker = false  // 是否显示文档选择器
    @State private var selectedDocIds: Set<String> = []  // 选中的文档ID
    @State private var showChatHistory = false  // 是否显示会话记录对话框
    
    var body: some View {
        ZStack {
            // 背景
            backgroundView
            
            VStack(spacing: 0) {
                // 标题栏
                headerView
                
                // 聊天消息区域
                chatMessagesView
                
                // 操作按钮组
                ChatActionButtons(
                    showThink: $showThink,
                    language: $language,
                    showDocumentQuery: $showDocumentQuery
                )
                
                // 底部输入栏
                inputBarView
            }
        }
        .onAppear {
            loadTenantAndModel()
            // 初始化聊天ID
            if currentChatId.isEmpty {
                currentChatId = generateChatId()
            }
        }
        .overlay(tenantListOverlay)
        .overlay(modelListOverlay)
        .overlay(loadingOverlay)
        .overlay(documentPickerOverlay)
        .overlay(chatHistoryOverlay)
        .actionSheet(isPresented: $showMenu) {
            menuActionSheet
        }
        .onReceive(webSocketManager.$currentResponse) { newResponse in
            // 监听WebSocket响应，流式更新消息
            if isReceivingMessage && !newResponse.isEmpty {
                currentAIResponse = newResponse
                updateLastAIMessage(content: currentAIResponse)
            }
        }
        .onReceive(webSocketManager.$isReceiving) { isReceiving in
            isReceivingMessage = isReceiving
            if !isReceiving && !currentAIResponse.isEmpty {
                // 消息接收完成，重置当前响应
                currentAIResponse = ""
            }
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
            .onChange(of: messages.last?.content) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    /// 底部输入栏视图
    private var inputBarView: some View {
        MessageInputBar(
            messageText: $inputMessage,
            isSending: isReceivingMessage,
            onSend: sendMessage,
            onClear: clearAllMessages,
            selectedDocCount: selectedDocIds.count,
            showDocumentSelectionButton: showDocumentQuery,  // 根据查询文档按钮状态控制显示
            onDocumentPicker: { showDocumentPicker = true }
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
    
    /// 文档选择器覆盖层
    @ViewBuilder
    private var documentPickerOverlay: some View {
        if showDocumentPicker {
            DocumentPickerDialog(
                isPresented: $showDocumentPicker,
                onConfirm: { selectedIds in
                    selectedDocIds = selectedIds
                    // 如果选择了文档，保持查询文档按钮激活状态
                    if !selectedIds.isEmpty {
                        showDocumentQuery = true
                    } else {
                        // 如果没有选中文档，可以选择是否关闭查询文档按钮
                        // 这里保持查询文档按钮状态不变，让用户手动关闭
                    }
                    print("✅ 已选择 \(selectedIds.count) 个文档")
                }
            )
        }
    }
    
    @ViewBuilder
    private var chatHistoryOverlay: some View {
        if showChatHistory {
            ChatHistoryDialog(
                isPresented: $showChatHistory,
                onSessionSelected: { chatId in
                    loadChatHistory(chatId: chatId)
                }
            )
        }
    }
    
    /// 菜单选项
    private var menuActionSheet: ActionSheet {
        ActionSheet(
            title: Text("菜单"),
            buttons: [
                .default(Text("会话记录")) { showChatHistory = true },  // 使用 showChatHistory
                .default(Text("上传文档")) { /* 后续实现 */ },
                .default(Text("我的文档")) { /* 后续实现 */ },
                .default(Text("设置提示词")) { /* 后续实现 */ },
                .default(Text("我的收藏提示词")) { /* 后续实现 */ },
                .cancel(Text("取消"))
            ]
        )
    }
    
    // MARK: - 辅助方法
    
    /// 生成32位UUID（去掉连字符）
    private func generateChatId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    /// 滚动到底部
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    /// 清空所有消息
    private func clearAllMessages() {
        messages.removeAll()
        currentChatId = generateChatId()
        currentAIResponse = ""
        selectedDocIds.removeAll()  // 清空选中的文档
        showDocumentQuery = false   // 重置查询文档按钮状态
        webSocketManager.reset()
        print("🗑️ 已清空聊天内容，新chatId: \(currentChatId)")
    }
    
    /// 更新最后一条AI消息（流式追加）
    private func updateLastAIMessage(content: String) {
        if let lastIndex = messages.lastIndex(where: { !$0.isUser }) {
            // 更新已存在的AI消息
            messages[lastIndex] = ChatMessage(content: content, isUser: false)
        } else {
            // 创建新的AI消息
            messages.append(ChatMessage(content: content, isUser: false))
        }
    }
    
    /// 发送消息
    private func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isReceivingMessage else { return }
        guard let model = appState.currentModel else {
            print("❌ 未选择模型")
            return
        }
        guard let tenant = appState.currentTenant else {
            print("❌ 未选择租户")
            return
        }
        
        let userMessageContent = inputMessage
        let userMessage = ChatMessage(content: userMessageContent, isUser: true)
        messages.append(userMessage)
        
        inputMessage = ""
        
        // 确定消息类型：如果选择了文档且查询文档按钮激活，则类型为document
        let messageType = (showDocumentQuery && !selectedDocIds.isEmpty) ? "document" : ""
        // 传递选中的文档ID（只有在查询文档激活时才传递）
        let docIds = (showDocumentQuery && !selectedDocIds.isEmpty) ? Array(selectedDocIds) : []
        
        // 连接WebSocket发送消息
        webSocketManager.connect(
            modelId: model.id,
            chatId: currentChatId,
            tenantId: tenant.id,
            prompt: userMessageContent,
            showThink: showThink,
            language: language,
            docIds: docIds,
            type: messageType,
            onMessage: { text in
                // 流式接收消息，更新最后一条AI消息
                DispatchQueue.main.async {
                    self.currentAIResponse += text
                    self.updateLastAIMessage(content: self.currentAIResponse)
                }
            },
            onComplete: {
                DispatchQueue.main.async {
                    self.isReceivingMessage = false
                    self.currentAIResponse = ""
                    print("✅ 消息接收完成")
                }
            }
        )
        
        isReceivingMessage = true
        currentAIResponse = ""
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
            appState.currentTenant = matchedTenant
        } else if let firstTenant = tenants.first {
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
            appState.currentModel = matchedModel
        } else if let firstModel = models.first {
            appState.saveCurrentModel(firstModel)
        }
    }
    


    private func loadChatHistory(chatId: String) {
        isLoading = true
        print("🔄 开始加载会话记录，chatId: \(chatId)")
        
        HTTPClient.shared.getChatHistoryByChatId(chatId: chatId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let histories):
                    print("✅ 获取到会话记录，共 \(histories.count) 条")
                    
                    // 打印每条记录的详细信息
                    for (index, history) in histories.enumerated() {
                        print("📝 历史记录[\(index)]:")
                        print("   - prompt: \(history.prompt)")
                        print("   - thinkContent: \(history.thinkContent ?? "无思考内容")")
                        print("   - responseContent: \(history.responseContent ?? "无响应内容")")
                        print("   - 完整AI内容: \(history.getFullAIResponse())")
                    }
                    
                    // 清空现有消息
                    messages.removeAll()
                    // 设置当前chatId
                    currentChatId = chatId
                    // 转换历史记录为消息列表
                    convertHistoryToMessages(histories)
                    print("✅ 加载会话记录成功，已显示 \(messages.count) 条消息")
                    
                case .failure(let error):
                    print("❌ 加载会话记录失败: \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
    }

    /// 将历史记录转换为消息列表
    private func convertHistoryToMessages(_ histories: [ChatHistory]) {
        print("🔄 开始转换历史记录为消息列表...")
        
        // 按时间排序（假设createTime是创建时间）
        let sortedHistories = histories.sorted { history1, history2 in
            guard let time1 = history1.createTime,
                  let time2 = history2.createTime else {
                return false
            }
            return time1 < time2
        }
        
        for (index, history) in sortedHistories.enumerated() {
            print("📝 处理第\(index + 1)条记录:")
            
            // 添加用户消息
            let userMessage = ChatMessage(content: history.prompt, isUser: true)
            messages.append(userMessage)
            print("   ✅ 添加用户消息: \(history.prompt)")
            
            // 构建AI消息内容
            var aiContent = ""
            
            // 添加思考内容
            if let thinkContent = history.thinkContent, !thinkContent.isEmpty {
                aiContent += "<think>\(thinkContent)</think>"
                print("   ✅ 添加思考内容: \(thinkContent.prefix(50))...")
            }
            
            // 添加响应正文
            if let responseContent = history.responseContent, !responseContent.isEmpty {
                aiContent += responseContent
                print("   ✅ 添加响应内容: \(responseContent.prefix(50))...")
            }
            
            // 如果AI内容为空，使用默认提示
            if aiContent.isEmpty {
                aiContent = "暂无回复内容"
                print("   ⚠️ AI内容为空，使用默认提示")
            }
            
            // 添加AI消息
            let aiMessage = ChatMessage(content: aiContent, isUser: false)
            messages.append(aiMessage)
            print("   ✅ 添加AI消息完成")
        }
        
        print("✅ 转换完成，共 \(messages.count) 条消息（\(messages.filter { $0.isUser }.count) 条用户消息，\(messages.filter { !$0.isUser }.count) 条AI消息）")
    }

    /// 滚动到底部的辅助方法
    private func scrollToBottomOnNextUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let lastMessage = messages.last {
                // 需要使用 ScrollViewReader 来滚动，这里需要在视图中实现
                // 暂时留空，后续完善
            }
        }
    }

}

#Preview {
    HomePage()
}
