import Foundation

/// 提示词模型
struct Prompt: Codable, Identifiable {
    let id: String
    let tenantId: String
    let userId: String
    let createTime: String?
    let updateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tenantId
        case userId
        case createTime
        case updateTime
    }
}
