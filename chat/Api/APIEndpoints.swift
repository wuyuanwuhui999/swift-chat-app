// config/APIEndpoints.swift

import Foundation

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
    case getChatHistory
    case getChatHistoryByChatId
    case uploadDoc
    case deleteDoc(String)  // 添加 deleteDoc，关联值传递 docId
    
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
        case .getChatHistory:
            return Constants.API.getChatHistory
        case .getChatHistoryByChatId:
            return Constants.API.getChatHistoryByChatId
        case .uploadDoc:
            return Constants.API.uploadDoc
        case .deleteDoc(let docId):
            // 替换路径中的 {docId} 参数
            return Constants.API.deleteDoc.replacingOccurrences(of: "{docId}", with: docId)
        }
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendEmailVertifyCode, .loginByEmail, .logout, .createDir, .uploadDoc:
            return "POST"
        case .getUserData, .getUserTenantList, .getModelList, .getDirectoryList, .getDocListByDirId, .getChatHistory, .getChatHistoryByChatId:
            return "GET"
        case .deleteDoc:
            return "DELETE"  // 删除文档使用 DELETE 方法
        }
    }
    
    func url(baseURL: String) -> URL? {
        let components = URLComponents(string: baseURL + path)
        return components?.url
    }
}
