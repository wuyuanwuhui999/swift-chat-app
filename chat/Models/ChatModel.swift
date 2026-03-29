import Foundation

// 聊天模型
struct ChatModel: Codable, Identifiable {
    let id: String
    let modelName: String
    let updateTime: String
    let createTime: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case modelName
        case updateTime
        case createTime
    }
}
