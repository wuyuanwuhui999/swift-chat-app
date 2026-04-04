import SwiftUI

/// 会话记录列表视图组件
struct ChatSessionListView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var sessions: [ChatSessionGroup] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var hasMoreData = true
    @State private var isLoadingMore = false
    
    let onSessionSelected: (String) -> Void  // 返回选中的chatId
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 半透明遮罩层
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                // 对话框内容 - 从底部弹出
                VStack(spacing: 0) {
                    // 标题栏
                    headerView
                    
                    // 可滚动的内容区域
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoading {
                                ProgressView()
                                    .padding(.vertical, Dimens.largeMargin)
                            } else if sessions.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(sessions) { session in
                                    SessionRow(
                                        session: session,
                                        onTap: {
                                            onSessionSelected(session.chatId)
                                            isPresented = false
                                        }
                                    )
                                }
                                
                                // 加载更多指示器
                                if hasMoreData && !isLoadingMore {
                                    ProgressView()
                                        .padding(.vertical, Dimens.middleMargin)
                                        .onAppear {
                                            loadMoreSessions()
                                        }
                                }
                            }
                        }
                    }
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
            loadChatSessions()
        }
    }
    
    /// 标题栏视图
    private var headerView: some View {
        Text("会话记录")
            .font(.system(size: Dimens.middleFont))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Dimens.middleMargin)
            .background(Colors.whiteColor)
            .overlay(
                Rectangle()
                    .fill(Colors.grayColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "message")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            Text("暂无会话记录")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 加载会话记录列表
    private func loadChatSessions() {
        isLoading = true
        currentPage = 1
        sessions = []
        
        guard let tenantId = appState.currentTenant?.id else {
            isLoading = false
            return
        }
        
        HTTPClient.shared.getChatHistory(
            tenantId: tenantId,
            pageNum: currentPage,
            pageSize: 20
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (histories, total)):
                    // 按chatId分组，取每组的第一条数据
                    let grouped = Dictionary(grouping: histories) { $0.chatId }
                    var sessionGroups: [ChatSessionGroup] = []
                    
                    for (chatId, historyList) in grouped {
                        if let firstHistory = historyList.first {
                            let group = ChatSessionGroup(
                                chatId: chatId,
                                firstMessage: firstHistory.prompt,
                                updateTime: firstHistory.createTime,
                                timeAgo: firstHistory.timeAgo
                            )
                            sessionGroups.append(group)
                        }
                    }
                    
                    // 按更新时间倒序排序
                    sessions = sessionGroups.sorted { group1, group2 in
                        guard let time1 = group1.updateTime,
                              let time2 = group2.updateTime else {
                            return false
                        }
                        return time1 > time2
                    }
                    
                    // 判断是否还有更多数据
                    hasMoreData = sessions.count < total
                    
                case .failure(let error):
                    print("❌ 获取会话记录失败: \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
    }
    
    /// 加载更多会话记录
    private func loadMoreSessions() {
        guard !isLoadingMore && hasMoreData else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        guard let tenantId = appState.currentTenant?.id else {
            isLoadingMore = false
            return
        }
        
        HTTPClient.shared.getChatHistory(
            tenantId: tenantId,
            pageNum: currentPage,
            pageSize: 20
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (histories, total)):
                    // 按chatId分组，取每组的第一条数据
                    let grouped = Dictionary(grouping: histories) { $0.chatId }
                    var newSessions: [ChatSessionGroup] = []
                    
                    for (chatId, historyList) in grouped {
                        if let firstHistory = historyList.first {
                            let group = ChatSessionGroup(
                                chatId: chatId,
                                firstMessage: firstHistory.prompt,
                                updateTime: firstHistory.createTime,
                                timeAgo: firstHistory.timeAgo
                            )
                            newSessions.append(group)
                        }
                    }
                    
                    // 合并并去重
                    let existingChatIds = Set(sessions.map { $0.chatId })
                    let filteredNewSessions = newSessions.filter { !existingChatIds.contains($0.chatId) }
                    sessions.append(contentsOf: filteredNewSessions)
                    
                    // 重新排序
                    sessions.sort { group1, group2 in
                        guard let time1 = group1.updateTime,
                              let time2 = group2.updateTime else {
                            return false
                        }
                        return time1 > time2
                    }
                    
                    // 判断是否还有更多数据
                    hasMoreData = sessions.count < total
                    
                case .failure(let error):
                    print("❌ 加载更多会话记录失败: \(error.localizedDescription)")
                }
                isLoadingMore = false
            }
        }
    }
}

/// 会话记录行视图
struct SessionRow: View {
    let session: ChatSessionGroup
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                // 第一条消息内容
                Text(session.firstMessage)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // 更新时间
                Text(session.timeAgo)
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
        }
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#Preview {
    ChatSessionListView(
        isPresented: .constant(true),
        onSessionSelected: { chatId in
            print("选中会话: \(chatId)")
        }
    )
}
