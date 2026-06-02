//
//  Company.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import Foundation

/// 公司/租户模型（用于公司选择页面）
struct Company: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let description: String?
    let status: Int  // 0: 禁用, 1: 启用, 2: 停用
    let createDate: String?
    let updateDate: String?
    let createdBy: String
    let updatedBy: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case description
        case status
        case createDate
        case updateDate
        case createdBy
        case updatedBy
    }
    
    /// 状态是否启用
    var isActive: Bool {
        return status == 1
    }
}