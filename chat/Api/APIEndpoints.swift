//
//  APIEndpoints.swift
//  chat
//
//  Created by 吴文强 on 2026/3/25.
//

import Foundation

enum APIEndpoint {
    // 定义所有接口路径
    case login
    case register
    case getUserInfo
    case getMessages(page: Int, size: Int)
    case sendMessage
    case logout
    
    var path: String {
        switch self {
        case .login:
            return "/api/auth/login"
        case .register:
            return "/api/auth/register"
        case .getUserInfo:
            return "/api/user/info"
        case .getMessages:
            return "/api/messages"
        case .sendMessage:
            return "/api/messages/send"
        case .logout:
            return "/api/auth/logout"
        }
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendMessage:
            return "POST"
        case .getUserInfo, .getMessages:
            return "GET"
        case .logout:
            return "POST"
        }
    }
    
    func url(baseURL: String) -> URL? {
        var components = URLComponents(string: baseURL + path)
        
        // 处理分页参数
        if case .getMessages(let page, let size) = self {
            components?.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "size", value: "\(size)")
            ]
        }
        
        return components?.url
    }
}
