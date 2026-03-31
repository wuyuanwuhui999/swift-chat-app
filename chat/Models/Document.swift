import Foundation

/// 文档模型
struct Document: Codable, Identifiable {
    let id: String
    let name: String
    let ext: String
    let userId: String
    let createTime: String
    let updateTime: String
    let directoryId: String
    let directoryName: String?  // 改为可选类型，因为服务器可能返回 null
    var checked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ext
        case userId
        case createTime
        case updateTime
        case directoryId
        case directoryName
        case checked
    }
}
