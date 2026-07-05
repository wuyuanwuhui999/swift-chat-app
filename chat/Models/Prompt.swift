/// 提示词模型（用于列表展示）
struct Prompt: Codable, Identifiable {
    let id: String
    let tenantId: String
    let userId: String
    let prompt: String
    let createTime: String?
    let updateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tenantId
        case userId
        case prompt
        case createTime
        case updateTime
    }
}