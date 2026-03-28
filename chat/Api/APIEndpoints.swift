import Foundation

enum APIEndpoint {
    // 定义所有接口路径
    case login
    case register
    case logout
    case getUserData
    case sendEmailVertifyCode
    case loginByEmail
    
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
        }
    }
    
    var method: String {
        switch self {
        case .login, .register, .sendEmailVertifyCode, .loginByEmail, .logout:
            return "POST"
        case .getUserData:
            return "GET"
        }
    }
    
    func url(baseURL: String) -> URL? {
        let components = URLComponents(string: baseURL + path)
        return components?.url
    }
}
