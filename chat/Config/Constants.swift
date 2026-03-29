// config/Constants.swift
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
    
    // API路径
    struct API {
        static let login = "/service/user/login"
        static let register = "/service/user/register"
        static let getUserData = "/service/data/getUserData"
        static let logout = "/service/user/logout"
        static let sendEmailVertifyCode = "/service/user/sendEmailVertifyCode"
        static let loginByEmail = "/service/user/loginByEmail"
        static let getUserTenantList = "/service/tenant/getUserTenantList"
        static let getModelList = "/service/chat/getModelList"
    }
}
