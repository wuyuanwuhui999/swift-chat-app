import SwiftUI

/// 会话记录对话框组件
struct ChatHistoryDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var chatHistoryList: [ChatHistory] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var totalCount = 0
    @State private var hasMoreData = true
    
    let pageSize = 20
    
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
                            if isLoading && chatHistoryList.isEmpty {
                                // 加载中状态
                                ProgressView()
                                    .padding(.vertical, Dimens.largeMargin)
                            } else if chatHistoryList.isEmpty {
                                // 空状态
                                Text("暂无会话记录")
                                    .font(.system(size: Dimens.normalFont))
                                    .foregroundColor(Colors.grayColor)
                                    .padding(.vertical, Dimens.largeMargin)
                            } else {
                                // 按时间分组显示
                                let groupedHistory = groupHistoryByTime()
                                
                                ForEach(Array(groupedHistory.keys.sorted(by: >)), id: \.self) { timeKey in
                                    if let histories = groupedHistory[timeKey] {
                                        // 分类标题
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(timeKey)
                                                .font(.system(size: Dimens.normalFont))
                                                .foregroundColor(Colors.grayColor)
                                                .padding(.horizontal, Dimens.middleMargin)
                                                .padding(.vertical, Dimens.middleMargin)
                                                .background(Colors.pageBackgroundColor)
                                            
                                            // 会话记录列表
                                            ForEach(histories) { history in
                                                ChatHistoryItem(history: history)
                                            }
                                        }
                                    }
                                }
                                
                                // 加载更多指示器
                                if isLoadingMore {
                                    ProgressView()
                                        .padding(.vertical, Dimens.middleMargin)
                                } else if hasMoreData && !chatHistoryList.isEmpty {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear {
                                            loadMoreHistory()
                                        }
                                }
                            }
                        }
                        .padding(.vertical, Dimens.middleMargin)
                    }
                    
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
            loadChatHistory()
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - 视图组件
    
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
    
    /// 底部操作区域视图
    private var bottomActionView: some View {
        VStack(spacing: Dimens.middleMargin) {
            // 确定按钮
            Button(action: {
                isPresented = false
            }) {
                Text("关闭")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.white)
                    .frame(height: Dimens.btnHeight)
                    .frame(maxWidth: .infinity)
                    .background(Colors.primaryColor)
                    .cornerRadius(Dimens.btnHeight / 2)
            }
            .padding(.horizontal, Dimens.middleMargin)
        }
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    /// 会话记录项
    struct ChatHistoryItem: View {
        let history: ChatHistory
        
        var body: some View {
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                // 时间和信息
                HStack {
                    Text(history.timeAgo ?? "未知时间")
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                    
                    Spacer()
                }
                
                // 提示词内容 - 最多两行
                Text(history.prompt)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    // MARK: - 数据加载方法
    
    /// 按时间分组会话记录
    private func groupHistoryByTime() -> [String: [ChatHistory]] {
        var grouped: [String: [ChatHistory]] = [:]
        
        for history in chatHistoryList {
            let timeKey = getTimeKey(history.timeAgo ?? "未知")
            if grouped[timeKey] == nil {
                grouped[timeKey] = []
            }
            grouped[timeKey]?.append(history)
        }
        
        return grouped
    }
    
    /// 根据时间差获取分组键
    private func getTimeKey(_ timeAgo: String) -> String {
        if timeAgo.contains("刚刚") || timeAgo.contains("分钟前") {
            return "刚刚"
        } else if timeAgo.contains("小时前") {
            return "几小时前"
        } else if timeAgo.contains("天前") {
            return "几天前"
        } else if timeAgo.contains("个月内") {
            return "几月前"
        } else if timeAgo.contains("年前") {
            return "一年前"
        } else {
            return "更早"
        }
    }
    
    /// 加载会话记录
    private func loadChatHistory() {
        guard let tenantId = appState.currentTenant?.id else {
            print("❌ 未选择租户")
            return
        }
        
        isLoading = true
        currentPage = 1
        hasMoreData = true
        
        HTTPClient.shared.getChatHistory(
            tenantId: tenantId,
            pageNum: currentPage,
            pageSize: pageSize
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    chatHistoryList = response.list
                    totalCount = response.total
                    hasMoreData = response.list.count >= pageSize
                    print("✅ 获取会话记录成功，共 \(response.total) 条")
                case .failure(let error):
                    print("❌ 获取会话记录失败: \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
    }
    
    /// 加载更多会话记录
    private func loadMoreHistory() {
        guard !isLoadingMore, hasMoreData, let tenantId = appState.currentTenant?.id else {
            return
        }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        HTTPClient.shared.getChatHistory(
            tenantId: tenantId,
            pageNum: nextPage,
            pageSize: pageSize
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    chatHistoryList.append(contentsOf: response.list)
                    currentPage = nextPage
                    hasMoreData = response.list.count >= pageSize
                    print("✅ 加载更多会话记录成功，当前共 \(chatHistoryList.count) 条")
                case .failure(let error):
                    print("❌ 加载更多会话记录失败: \(error.localizedDescription)")
                }
                isLoadingMore = false
            }
        }
    }
}

#Preview {
    ChatHistoryDialog(isPresented: .constant(true))
}
