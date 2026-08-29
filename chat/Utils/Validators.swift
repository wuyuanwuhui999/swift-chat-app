//
//  Validators.swift
//  chat
//
//  Created by 吴文强 on 2026/7/7.
//

import Foundation

/// 表单校验工具（无状态，供各页面共用）
enum Validators {
    /// 校验模型地址格式：scheme 必须是 http/https，且能解析出非空 host
    /// - Parameter urlString: 已 trim 的地址字符串
    /// - Returns: 合法返回 true
    static func isValidBaseUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return false
        }
        return true
    }

    /// 校验邮箱格式（登录 / 注册 / 忘记密码 / 个人资料页共用同一段正则）
    /// - Parameter email: 待校验邮箱字符串
    /// - Returns: 合法返回 true
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
