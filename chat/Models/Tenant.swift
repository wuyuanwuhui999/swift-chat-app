// chat/chat/Models/Tenant.swift
// models/Tenant.swift
import Foundation

/// 租户状态枚举
/// 0: 禁用, 1: 启用, 2: 停用
enum TenantStatus: Int, Codable {
    case inactive = 0
    case active = 1
    case suspended = 2
    
    /// 转换为字符串表示
    var stringValue: String {
        switch self {
        case .active:
            return "ACTIVE"
        case .inactive:
            return "INACTIVE"
        case .suspended:
            return "SUSPENDED"
        }
    }
}

/// 租户模型
struct Tenant: Codable, Identifiable {
    let id: String
    let name: String
    let code: String
    let description: String?
    let status: TenantStatus
    let createDate: String?
    let updateDate: String?
    let createdBy: String?      // 改为可选类型
    let updatedBy: String?      // 改为可选类型
    let role: Int?              // 新增：当前用户在该租户中的角色 (0-普通用户，1-管理员，2-超级管理员)
    
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
    
    /// 格式化创建时间
    var formattedCreateDate: String {
        guard let createDate = createDate else { return "" }
        return formatDateString(createDate)
    }
    
    /// 格式化更新时间
    var formattedUpdateDate: String {
        guard let updateDate = updateDate else { return "" }
        return formatDateString(updateDate)
    }
    
    /// 格式化日期字符串
    private func formatDateString(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    /// 角色显示文本
    var roleText: String {
        guard let role = role else { return "" }
        switch role {
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
        return (role ?? 0) > 0
    }
}