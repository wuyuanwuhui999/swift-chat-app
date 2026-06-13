//
//  CompanyUser.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import Foundation

/// 公司用户模型（对应后端的 CompanyUserEntity）
struct CompanyUser: Codable, Identifiable {
    let id: String?
    let userId: String?
    let userAccount: String
    let username: String
    let telephone: String
    let email: String
    let sex: String
    let region: String?
    let avater: String?
    let sign: String
    let companyId: String?
    let positionId: String?
    let positionName: String?
    let departmentId: String?
    let departmentName: String?
    let role: Int?           // 角色：2-超级管理员，1-管理员，0-普通成员
    let joinDate: String?    // 加入时间
    let status: Int?         // 状态：0-禁用，1-正常
    let createBy: String?    // 创建人ID
    let createDate: String?
    let updateDate: String?
    let birthday: String?
    let password: String?
    let disabled: Int?
    let permission: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userAccount
        case username
        case telephone
        case email
        case sex
        case region
        case avater
        case sign
        case companyId
        case positionId
        case positionName
        case departmentId
        case departmentName
        case role
        case joinDate
        case status
        case createBy
        case createDate
        case updateDate
        case birthday
        case password
        case disabled
        case permission
    }
    
    /// 部门显示文本
    var displayDepartment: String {
        return departmentName ?? "未分配"
    }
    
    /// 职位显示文本
    var displayPosition: String {
        return positionName ?? "未分配"
    }
    
    /// 角色显示文本
    var roleText: String {
        guard let role = role else { return "" }
        switch role {
        case 2:
            return "超级管理员"
        case 1:
            return "管理员"
        default:
            return "普通成员"
        }
    }
    
    /// 是否显示角色标签
    var shouldShowRoleTag: Bool {
        return (role ?? 0) > 0
    }
}