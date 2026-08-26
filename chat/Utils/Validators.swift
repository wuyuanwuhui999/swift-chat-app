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
}
