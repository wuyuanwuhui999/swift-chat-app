//
//  BaseResponse.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

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
