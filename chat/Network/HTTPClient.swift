import Foundation
import CommonCrypto

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(statusCode: Int)
    case unauthorized
    case custom(message: String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "无返回数据"
        case .decodingError:
            return "数据解析失败"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let statusCode):
            return "服务器错误: \(statusCode)"
        case .unauthorized:
            return "未授权，请重新登录"
        case .custom(let message):
            return message
        }
    }
}

// network/HTTPClient.swift

class HTTPClient {
    static let shared = HTTPClient()
    private let session: URLSession
    private let baseURL = Constants.baseURL
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.Timeout.request
        configuration.timeoutIntervalForResource = Constants.Timeout.resource
        self.session = URLSession(configuration: configuration)
    }
    
    // 通用请求方法
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: String? = nil,
        parameters: [String: Any]? = nil,
        completion: @escaping (Result<BaseResponse<T>, NetworkError>) -> Void
    ) {
        guard let url = endpoint.url(baseURL: baseURL) else {
            print("❌ 无效的URL: \(endpoint.path)")
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method ?? endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加Authorization header
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔐 Authorization: \(authHeader)")
        }
        
        // 添加请求参数
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                // 打印请求参数
                print("📤 请求参数: \(parameters)")
            } catch {
                print("❌ 参数序列化失败: \(error)")
                completion(.failure(.custom(message: "参数序列化失败")))
                return
            }
        }
        
        // 打印请求信息
        print("🌐 请求URL: \(url)")
        print("📡 请求方法: \(request.httpMethod ?? "GET")")
        print("📋 请求头: \(request.allHTTPHeaderFields ?? [:])")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的响应")
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            print("📊 HTTP状态码: \(httpResponse.statusCode)")
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200...299:
                print("✅ 请求成功")
                break
            case 401:
                print("🔒 未授权，需要重新登录")
                DispatchQueue.main.async {
                    completion(.failure(.unauthorized))
                }
                return
            default:
                print("⚠️ 服务器错误: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                print("❌ 无返回数据")
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            // 打印响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 响应数据: \(jsonString)")
            } else {
                print("📥 响应数据长度: \(data.count) bytes")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<T>.self, from: data)
                print("✅ 数据解析成功，status: \(response.status), isSuccess: \(response.isSuccess)")
                if let msg = response.msg {
                    print("💬 服务器消息: \(msg)")
                }
                
                // 如果返回了token，保存它
                if let token = response.token {
                    print("🎫 获取到新token: \(token.prefix(20))...")
                    TokenManager.shared.saveToken(token)
                }
                
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                print("❌ 数据解析失败: \(error)")
                print("❌ 原始数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }
}

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// 在 HTTPClient 中添加新的请求方法
extension HTTPClient {
    // 登录专用方法
    func login(userAccount: String, password: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void) {
        let encryptedPassword = password.md5
        let parameters: [String: Any] = [
            "userAccount": userAccount,
            "password": encryptedPassword
        ]
        
        request(endpoint: .login, parameters: parameters) { (result: Result<BaseResponse<UserData>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let userData = response.data, let token = response.token {
                    let loginResponse = LoginResponse(userData: userData, token: token)
                    completion(.success(loginResponse))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "登录失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 获取用户数据
    func getUserData(completion: @escaping (Result<UserData, NetworkError>) -> Void) {
        request(endpoint: .getUserData) { (result: Result<BaseResponse<UserData>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let userData = response.data {
                    // 如果有新token，保存它
                    if let token = response.token {
                        TokenManager.shared.saveToken(token)
                        AppState.shared.updateToken(token)
                    }
                    completion(.success(userData))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "获取用户信息失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendEmailVerificationCode(email: String, completion: @escaping (Result<BaseResponse<EmptyData>, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "email": email
        ]
        
        request(endpoint: .sendEmailVertifyCode, parameters: parameters) { (result: Result<BaseResponse<EmptyData>, NetworkError>) in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 邮箱验证码登录
    func loginByEmail(email: String, code: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "email": email,
            "code": code
        ]
        
        request(endpoint: .loginByEmail, parameters: parameters) { (result: Result<BaseResponse<UserData>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let userData = response.data, let token = response.token {
                    let loginResponse = LoginResponse(userData: userData, token: token)
                    completion(.success(loginResponse))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "登录失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

}

// 登录响应模型
struct LoginResponse {
    let userData: UserData
    let token: String
}
