// chat/chat/Api/APIEndpoints.swift

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
    case getModelList(String)  // 改为必传参数，companyId 不能为 nil
    case getDirectoryList
    case getDocListByDirId
    case createDir
    case getChatHistory
    case getChatHistoryByChatId
    case uploadDoc(String, String)  // tenantId, directoryId
    case deleteDoc(String)
    case updateUser
    case updateAvater
    case vertifyUser
    case resetPassword
    case updatePassword
    case getPrompt
    case updatePrompt
    case getCompanyList

    case getTenantUserList
    case getCompanyUsers
    case addTenantUser(String, String)

    case addAdmin(String, String)
    case cancelAdmin(String, String)
    case searchCompanyUsers

    case addCompanyUser
    case searchTenantUsers    
    case getPositions

    case getPromptList
    case deletePrompt(String)
    case insertPrompt
    
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
        case .uploadDoc(let tenantId, let directoryId):
            return Constants.API.uploadDoc
                .replacingOccurrences(of: "{tenantId}", with: tenantId)
                .replacingOccurrences(of: "{directoryId}", with: directoryId)
        case .deleteDoc(let docId):
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
        case .getTenantUserList:
            return Constants.API.getTenantUserList
        case .getCompanyUsers:
            return Constants.API.getCompanyUsers
        case .addCompanyUser:
            return Constants.API.addCompanyUser
        case .addTenantUser(let tenantId, let userId):
            return Constants.API.addTenantUser
                .replacingOccurrences(of: "{tenantId}", with: tenantId)
                .replacingOccurrences(of: "{userId}", with: userId)
        case .addAdmin(let tenantId, let userId):
            return Constants.API.addAdmin
                .replacingOccurrences(of: "{tenantId}", with: tenantId)
                .replacingOccurrences(of: "{userId}", with: userId)
        case .cancelAdmin(let tenantId, let userId):
            return Constants.API.cancelAdmin
                .replacingOccurrences(of: "{tenantId}", with: tenantId)
                .replacingOccurrences(of: "{userId}", with: userId)
        case .searchCompanyUsers:
            return Constants.API.searchCompanyUsers
        case .searchTenantUsers:
            return Constants.API.searchTenantUsers
        case .getPositions:
            return Constants.API.getPositions
        case .getPromptList:
            return Constants.API.getPromptList
        case .deletePrompt(let promptId):
            return Constants.API.deletePrompt
                .replacingOccurrences(of: "{tenantId}", with: promptId)
        case .insertPrompt:
            return Constants.API.insertPrompt
        }
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendEmailVertifyCode, .loginByEmail, .logout, .createDir, .uploadDoc, .updateAvater, .vertifyUser, .resetPassword, .addTenantUser,.addCompanyUser,.insertPrompt:
            return "POST"
        case .getUserData, .getCompanyList, .getTenantList, .getModelList, .getDirectoryList, .getDocListByDirId, .getChatHistory, .getChatHistoryByChatId, .getPrompt, .getTenantUserList, .getCompanyUsers, .searchCompanyUsers,.searchTenantUsers,.getPositions,.getPromptList:
            return "GET"
        case .deleteDoc,.deletePrompt:
            return "DELETE"
        case .updateUser, .updatePassword, .updatePrompt, .addAdmin, .cancelAdmin:
            return "PUT"
        }
    }
    
    /// 构建带参数的 URL
    func url(baseURL: String) -> URL? {
        var components = URLComponents(string: baseURL + path)
        
        // 为 getModelList 添加 query 参数（companyId 是必传参数）
        if case .getModelList(let companyId) = self {
            components?.queryItems = [URLQueryItem(name: "companyId", value: companyId)]
        }
        
        return components?.url
    }
}
