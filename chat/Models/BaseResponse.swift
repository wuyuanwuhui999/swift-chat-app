import Foundation

// 统一接口返回格式
struct BaseResponse<T: Codable>: Codable {
    let data: T?
    let token: String?
    let status: String
    let msg: String?
    let total: Int?
    
    enum CodingKeys: String, CodingKey {
        case data
        case token
        case status
        case msg
        case total
    }
    
    // 判断接口是否成功
    var isSuccess: Bool {
        return status == "SUCCESS"
    }
    
    // 自定义解码，处理各种数据类型
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解码基本字段
        token = try container.decodeIfPresent(String.self, forKey: .token)
        status = try container.decode(String.self, forKey: .status)
        msg = try container.decodeIfPresent(String.self, forKey: .msg)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        
        // 处理 data 字段，如果 T 是 String 类型但返回的是对象等情况
        if T.self == EmptyData.self {
            // 如果期望空数据，忽略 data
            data = nil
        } else {
            // 尝试解码 data
            data = try container.decodeIfPresent(T.self, forKey: .data)
        }
    }
}

// 用于处理data为空的响应
struct EmptyData: Codable {}

// 用于处理data为字符串的响应
struct StringData: Codable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
}

// 用于处理data为数字的响应
struct NumberData: Codable {
    let value: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Double.self)
    }
}
