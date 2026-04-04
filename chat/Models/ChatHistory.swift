import Foundation

/// 聊天历史记录模型
struct ChatHistory: Codable, Identifiable {
    let id: Int
    let chatId: String
    let prompt: String          // 用户消息
    let thinkContent: String?   // AI思考内容
    let responseContent: String? // AI响应正文
    let createTime: String?
    let updateTime: String?
    var timeAgo: String = ""    // 时间差显示（非数据库字段）
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatId
        case prompt
        case thinkContent
        case responseContent
        case createTime
        case updateTime
    }
    
    /// 获取完整的AI回复内容（思考内容+正文）
    func getFullAIResponse() -> String {
        var fullResponse = ""
        if let think = thinkContent, !think.isEmpty {
            fullResponse += "<think>\(think)</think>"
        }
        if let response = responseContent, !response.isEmpty {
            fullResponse += response
        }
        return fullResponse
    }
    
    /// 计算时间差（用于显示）
    mutating func calculateTimeAgo() {
        guard let createTime = createTime else {
            timeAgo = "刚刚"
            return
        }
        
        // 解析时间格式 "yyyy-MM-dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        if let date = formatter.date(from: createTime) {
            let now = Date()
            let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
            
            if let day = components.day, day > 0 {
                timeAgo = "\(day)天前"
            } else if let hour = components.hour, hour > 0 {
                timeAgo = "\(hour)小时前"
            } else if let minute = components.minute, minute > 0 {
                timeAgo = "\(minute)分钟前"
            } else {
                timeAgo = "刚刚"
            }
        } else {
            print("⚠️ 时间解析失败: \(createTime)")
            timeAgo = "未知时间"
        }
    }
}

/// 会话记录分组模型（用于展示会话列表）
struct ChatSessionGroup: Identifiable {
    let id = UUID()
    let chatId: String
    let firstMessage: String  // 第一条消息内容
    let updateTime: String?   // 最后更新时间
    let timeAgo: String       // 时间差显示
}
