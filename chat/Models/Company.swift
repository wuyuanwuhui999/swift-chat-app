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
    let role: Int?  // 当前用户在公司中的角色，1=普通管理员，2=超级管理员
    
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
        case role
    }
    
    /// 状态是否启用
    var isActive: Bool {
        return status == 1
    }
    
    /// 当前用户是否为普通管理员（role == 1）
    var isNormalAdmin: Bool {
        return role == 1
    }
    
    /// 当前用户是否为超级管理员（role == 2）
    var isSuperAdmin: Bool {
        return role == 2
    }
    
    /// 当前用户是否为管理员（role == 1 或 role == 2）
    var isAdmin: Bool {
        return role == 1 || role == 2
    }
}