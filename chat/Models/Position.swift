//
//  Position.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import Foundation

/// 职位模型
/// 数据来源：GET /service/company/getPositions（入参 departmentId）
/// 说明：添加公司成员只提交 positionId，后端可由 positionId 反查 departmentId，故 departmentId 不落库
struct Position: Codable, Identifiable {
    /// 职位 ID（Picker tag、addCompanyUser 的 positionId）
    let id: String
    /// 职位名称（Picker 展示）
    let positionName: String
    /// 所属部门 ID
    let departmentId: String
    /// 职位描述（后端可能不返回）
    let description: String?
    /// 创建时间（后端可能不返回）
    let createTime: String?
}
