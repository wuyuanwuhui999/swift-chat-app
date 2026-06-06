//
//  ChatHistory.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

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
    /// 支持解析多种时间格式：
    /// - ISO 8601: "2026-06-05T22:12:47"
    /// - 标准格式: "2026-06-05 22:12:47"
    mutating func calculateTimeAgo() {
        guard let createTime = createTime else {
            timeAgo = "刚刚"
            return
        }
        
        // 尝试解析 ISO 8601 格式（无毫秒，无时区）
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.timeZone = TimeZone.current
        
        // 尝试解析标准格式
        let standardFormatter = DateFormatter()
        standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        standardFormatter.locale = Locale(identifier: "en_US_POSIX")
        standardFormatter.timeZone = TimeZone.current
        
        var date: Date?
        
        // 先尝试 ISO 8601 格式
        if let parsedDate = isoFormatter.date(from: createTime) {
            date = parsedDate
            print("✅ ISO格式解析成功: \(createTime) -> \(parsedDate)")
        }
        // 再尝试标准格式
        else if let parsedDate = standardFormatter.date(from: createTime) {
            date = parsedDate
            print("✅ 标准格式解析成功: \(createTime) -> \(parsedDate)")
        }
        
        guard let validDate = date else {
            print("⚠️ 时间解析失败，不支持格式: \(createTime)")
            timeAgo = "未知时间"
            return
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: validDate, to: now)
        
        if let day = components.day, day > 0 {
            timeAgo = "\(day)天前"
        } else if let hour = components.hour, hour > 0 {
            timeAgo = "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            timeAgo = "\(minute)分钟前"
        } else {
            timeAgo = "刚刚"
        }
        
        print("📅 时间计算完成: \(createTime) -> \(timeAgo)")
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
