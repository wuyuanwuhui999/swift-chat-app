import Foundation

struct UserData: Codable {
    var id: String?
    var userAccount: String
    var createDate: String?
    var updateDate: String?
    var username: String
    var telephone: String
    var email: String
    var avater: String?
    var birthday: String?  // 改为可选类型
    var sex: Int
    var role: String?
    var password: String?
    var sign: String
    var region: String?
    var disabled: Int?
    var permission: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userAccount
        case createDate
        case updateDate
        case username
        case telephone
        case email
        case avater
        case birthday
        case sex
        case role
        case password
        case sign
        case region
        case disabled
        case permission
    }
}
