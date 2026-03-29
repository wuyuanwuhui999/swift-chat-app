import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool  // true: 用户消息，false: AI回复
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}
