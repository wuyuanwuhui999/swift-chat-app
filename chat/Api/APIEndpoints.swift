// config/APIEndpoints.swift
import Foundation

// 添加新的枚举值
enum APIEndpoint {
    // 定义所有接口路径
    case login
    case register
    case logout
    case getUserData
    case sendEmailVertifyCode
    case loginByEmail
    case getUserTenantList
    case getModelList
    case getDirectoryList
    case getDocListByDirId
    case createDir
    case getChatHistoryByChatId
    
    var path: String {
        switch self {
        case .login:
            return Constants.API.login
        case .register:
            return Constants.API.register
        case .logout:
            return Constants.API.logout
        case .getUserData:
            return Constants.API.getUserData
        case .sendEmailVertifyCode:
            return Constants.API.sendEmailVertifyCode
        case .loginByEmail:
            return Constants.API.loginByEmail
        case .getUserTenantList:
            return Constants.API.getUserTenantList
        case .getModelList:
            return Constants.API.getModelList
        case .getDirectoryList:
            return Constants.API.getDirectoryList
        case .getDocListByDirId:
            return Constants.API.getDocListByDirId
        case .createDir:
            return Constants.API.createDir
        case .getChatHistoryByChatId:
            return Constants.API.getChatHistoryByChatId
        }
        
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendEmailVertifyCode, .loginByEmail, .logout, .createDir:
            return "POST"
        case .getUserData, .getUserTenantList, .getModelList, .getDirectoryList, .getDocListByDirId,.getChatHistoryByChatId:
            return "GET"
        }
    }
    
    func url(baseURL: String) -> URL? {
        let components = URLComponents(string: baseURL + path)
        return components?.url
    }
}
