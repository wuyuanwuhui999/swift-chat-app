import Foundation

/// 会话历史记录分页响应模型
struct ChatHistoryResponse {
    let total: Int
    let list: [ChatHistory]
}
