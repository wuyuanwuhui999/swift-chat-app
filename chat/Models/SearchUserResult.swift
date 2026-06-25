//
//  SearchUserResult.swift
//  chat
//
//  Created by 吴文强 on 2026/6/25.
//

import Foundation

/// 用户搜索结果模型
/// 继承自 User，增加 checked 字段表示是否已添加到公司/租户
struct SearchUserResult: Codable, Identifiable {
    let id: String?
    let userAccount: String
    let createDate: String?
    let updateDate: String?
    let username: String
    let telephone: String
    let email: String
    let avater: String?
    let birthday: String?
    let sex: String
    let role: String?
    let password: String?
    let sign: String?          // ✅ 改为可选类型，兼容后端不返回该字段的情况
    let region: String?
    let disabled: Int?
    let permission: Int?
    let checked: Int?          // 0: 未添加, 1: 已添加
    
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
        case checked
    }
    
    /// 是否已添加
    var isAdded: Bool {
        return checked == 1
    }
}