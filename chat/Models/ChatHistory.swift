import Foundation

/// 会话记录模型
struct ChatHistory: Codable, Identifiable {
    let id: Int
    let userId: String
    let files: String?
    let chatId: String
    let prompt: String
    let systemPrompt: String?  // 改为可选类型，因为接口可能不返回此字段
    let content: String
    let createTime: String
    let thinkContent: String?
    let responseContent: String?
    var timeAgo: String?  // 前端计算的时间差
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case files
        case chatId
        case prompt
        case systemPrompt = "SystemPrompt"
        case content
        case createTime
        case thinkContent
        case responseContent
        case timeAgo
    }
    
    /// 计算时间差
    mutating func calculateTimeAgo() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let createDate = formatter.date(from: createTime) else {
            timeAgo = "未知时间"
            return
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: createDate, to: now)
        
        if let minute = components.minute, minute < 1 {
            timeAgo = "刚刚"
        } else if let minute = components.minute, minute < 60 {
            timeAgo = "\(minute)分钟前"
        } else if let hour = components.hour, hour < 24 {
            timeAgo = "\(hour)小时前"
        } else if let day = components.day, day < 30 {
            timeAgo = "\(day)天前"
        } else if let month = components.month, month < 12 {
            timeAgo = "\(month)个月内"
        } else if let year = components.year {
            timeAgo = "\(year)年前"
        } else {
            timeAgo = "未知时间"
        }
    }
}

/// 会话记录分页响应
struct ChatHistoryResponse: Codable {
    let total: Int
    let list: [ChatHistory]
}
