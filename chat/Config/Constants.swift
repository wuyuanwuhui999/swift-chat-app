import Foundation
// 在 Constants 结构体中添加新的 API 路径
struct Constants {
    // API基础域名
    static let baseURL = "http://127.0.0.1:3000"
    
    // WebSocket 地址
    static let webSocketURL = "ws://127.0.0.1:3000/service/chat/ws/chat"
    
    // 系统提示词
    static let systemPrompt = "你叫小吴同学，是一个无所不能的AI助手，上知天文下知地理，请用小吴同学的身份回答问题。"
    
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
        // 新增接口
        static let getDirectoryList = "/service/chat/getDirectoryList"
        static let getDocListByDirId = "/service/chat/getDocListByDirId"
        static let createDir = "/service/chat/createDir"
        
        static let getChatHistory = "/service/chat/getChatHistory"  // 新增
    }
}
