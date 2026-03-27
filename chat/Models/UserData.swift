//
//  UserData.swift
//  chat
//
//  Created by 吴文强 on 2026/3/27.
//

import Foundation

struct UserData: Codable {
    let id: String?
    let userAccount: String
    let createDate: String?
    let updateDate: String?
    let username: String
    let telephone: String
    let email: String
    let avater: String?
    let birthday: String
    let sex: Int
    let role: String?
    let password: String
    let sign: String
    let region: String
    let disabled: Int?
    let permission: Int?
    
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
    }
}
