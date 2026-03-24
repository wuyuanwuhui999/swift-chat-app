//
//  TokenManager.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import Foundation

class TokenManager {
    static let shared = TokenManager()
    private let tokenKey = "auth_token"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // 保存token
    func saveToken(_ token: String) {
        userDefaults.set(token, forKey: tokenKey)
    }
    
    // 获取token
    func getToken() -> String? {
        return userDefaults.string(forKey: tokenKey)
    }
    
    // 清除token
    func clearToken() {
        userDefaults.removeObject(forKey: tokenKey)
    }
    
    // 获取格式化的Authorization header
    func getAuthorizationHeader() -> String? {
        guard let token = getToken() else { return nil }
        return "Bearer \(token)"
    }
    
    // 检查是否已登录
    var isLoggedIn: Bool {
        return getToken() != nil
    }
}
