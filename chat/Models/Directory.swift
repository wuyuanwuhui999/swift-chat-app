// models/Directory.swift
import Foundation

/// 目录模型
struct Directory: Codable, Identifiable {
    let id: String
    let userId: String?
    let directory: String
    let tenantId: String
    let createTime: String?
    let updateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case directory
        case tenantId
        case createTime
        case updateTime
    }
}
