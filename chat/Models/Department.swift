//
//  Department.swift
//  chat
//
//  Created by 吴文强 on 2026/6/11.
//

import Foundation

/// 部门模型
/// 数据来源：GET /service/company/getDepartments（入参 companyId）
struct Department: Codable, Identifiable {
    /// 部门 ID（Picker tag、getPositions 入参）
    let id: String
    /// 所属公司 ID
    let companyId: String
    /// 部门名称（Picker 展示）
    let departmentName: String
    /// 部门描述（后端可能不返回）
    let description: String?
    /// 创建时间（后端可能不返回）
    let createTime: String?
}
