//
//  TenantUser.swift
//  chat
//
//  Created by 吴文强 on 2026/6/7.
//

import Foundation

/// 租户用户模型
struct TenantUser: Codable, Identifiable {
    let id: String
    let tenantId: String
    let tenantName: String?  // 改为可选类型，因为后端可能返回 null
    let userId: String
    let userAccount: String
    let roleType: Int // 用户角色 (0-普通用户，1-租户管理员，2-超级管理员)
    let joinDate: String?
    let createBy: String?
    let username: String
    let avater: String?
    let disabled: Int
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case tenantId
        case tenantName
        case userId
        case userAccount
        case roleType
        case joinDate
        case createBy
        case username
        case avater
        case disabled
        case email
    }
    
    /// 角色显示文本
    var roleText: String {
        switch roleType {
        case 1:
            return "管理员"
        case 2:
            return "超级管理员"
        default:
            return ""
        }
    }
    
    /// 是否显示角色标签
    var shouldShowRoleTag: Bool {
        return roleType > 0
    }
    
    /// 获取租户名称（带默认值）
    var displayTenantName: String {
        return tenantName ?? ""
    }
}