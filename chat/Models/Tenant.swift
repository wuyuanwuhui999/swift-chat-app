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
}
