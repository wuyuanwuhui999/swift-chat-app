//
//  Constants.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import Foundation

struct Constants {
    // API基础域名
    static let baseURL = "http://127.0.0.1:3000"
    
    // 其他常量配置
    struct Timeout {
        static let request: TimeInterval = 30
        static let resource: TimeInterval = 60
    }
    
    struct Cache {
        static let maxAge: TimeInterval = 3600 * 24 * 30 // 1个月
    }
}
