// chat/chat/Models/ChatModel.swift
import Foundation

/// 聊天模型（用于列表展示和操作）
struct ChatModel: Codable, Identifiable {
    let id: String
    let modelName: String
    let type: String          // 模型类型：ollama 或 online
    let baseUrl: String       // 模型地址
    let apiKey: String?       // API Key（可选）
    let companyId: String     // 所属公司ID
    let updateTime: String?
    let createTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case modelName
        case type
        case baseUrl
        case apiKey
        case companyId
        case updateTime
        case createTime
    }
}
