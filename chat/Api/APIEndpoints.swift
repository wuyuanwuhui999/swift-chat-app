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
    case getTenantList
    case getModelList
    case getDirectoryList
    case getDocListByDirId
    case createDir
    case getChatHistory
    case getChatHistoryByChatId
    case uploadDoc
    case deleteDoc(String)  // 添加 deleteDoc，关联值传递 docId
    case updateUser
    case updateAvater
    case vertifyUser
    case resetPassword
    case updatePassword
    case getPrompt
    case updatePrompt
    case getCompanyList

    case getTenantUser
    case getTenantUserList
    case getCompanyUsers
    case addTenantUser(String, String)
    
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
        case .getTenantList:
            return Constants.API.getTenantList
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
        case .updateUser:
            return Constants.API.updateUser
        case .updateAvater:
            return Constants.API.updateAvater
        case .vertifyUser:
            return Constants.API.vertifyUser
        case .resetPassword:
            return Constants.API.resetPassword
        case .updatePassword:
            return Constants.API.updatePassword
        case .getPrompt:
            return Constants.API.getPrompt
        case .updatePrompt:
            return Constants.API.updatePrompt
        case .getCompanyList:
            return Constants.API.getCompanyList
        case .getTenantUser:
            return Constants.API.getTenantUser
        case .getTenantUserList:
            return Constants.API.getTenantUserList
        case .getCompanyUsers:
            return Constants.API.getCompanyUsers
        case .addTenantUser(let tenantId, let userId):
            return Constants.API.addTenantUser
                .replacingOccurrences(of: "{tenantId}", with: tenantId)
                .replacingOccurrences(of: "{userId}", with: userId)
        }
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendEmailVertifyCode, .loginByEmail, .logout, .createDir, .uploadDoc,.updateAvater, .vertifyUser,.resetPassword,.addTenantUser:
                return "POST"
            case .getUserData, .getCompanyList, .getTenantList, .getModelList, .getDirectoryList, .getDocListByDirId, .getChatHistory, .getChatHistoryByChatId,.getPrompt,.getTenantUser, .getTenantUserList, .getCompanyUsers:
                return "GET"
            case .deleteDoc:
                return "DELETE"  // 删除文档使用 DELETE 方法
        case .updateUser,.updatePassword,.updatePrompt:
               return "PUT"
        }
    }
    
    func url(baseURL: String) -> URL? {
        let components = URLComponents(string: baseURL + path)
        return components?.url
    }
}
