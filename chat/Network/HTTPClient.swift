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
            print("❌ 无效的URL")
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        // 使用 endpoint.method 或传入的 method 参数
        request.httpMethod = method ?? endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加Authorization header
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🔐 Authorization: \(authHeader)")
        }
        
        // 添加请求参数（仅对 POST/PUT 等方法）
        if let parameters = parameters, !parameters.isEmpty {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                print("📤 请求参数: \(parameters)")
            } catch {
                print("❌ 参数序列化失败: \(error)")
                completion(.failure(.custom(message: "参数序列化失败")))
                return
            }
        }
        
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
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ 原始数据: \(jsonString)")
                }
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
    
    /// 获取用户租户列表
    func getUserTenantList(completion: @escaping (Result<[Tenant], NetworkError>) -> Void) {
        request(endpoint: .getUserTenantList) { (result: Result<BaseResponse<[Tenant]>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let tenants = response.data {
                    completion(.success(tenants))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "获取租户列表失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 获取模型列表
    func getModelList(completion: @escaping (Result<[ChatModel], NetworkError>) -> Void) {
        request(endpoint: .getModelList) { (result: Result<BaseResponse<[ChatModel]>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let models = response.data {
                    completion(.success(models))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "获取模型列表失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 获取目录列表
    func getDirectoryList(tenantId: String, completion: @escaping (Result<[Directory], NetworkError>) -> Void) {
        let parameters: [String: Any] = ["tenantId": tenantId]
        
        // 构建带参数的URL
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getDirectoryList) else {
            completion(.failure(.invalidURL))
            return
        }
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<[Directory]>.self, from: data)
                if response.isSuccess, let directories = response.data {
                    DispatchQueue.main.async {
                        completion(.success(directories))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取目录列表失败")))
                    }
                }
            } catch {
                print("❌ 解析失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 获取目录下的文档列表
    func getDocListByDirId(tenantId: String, directoryId: String, completion: @escaping (Result<[Document], NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "tenantId": tenantId,
            "directoryId": directoryId
        ]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getDocListByDirId) else {
            completion(.failure(.invalidURL))
            return
        }
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<[Document]>.self, from: data)
                if response.isSuccess, let documents = response.data {
                    DispatchQueue.main.async {
                        completion(.success(documents))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取文档列表失败")))
                    }
                }
            } catch {
                print("❌ 解析失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 创建目录
    func createDirectory(directory: String, tenantId: String, completion: @escaping (Result<Directory, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "directory": directory,
            "tenantId": tenantId
        ]
        
        request(endpoint: .createDir, parameters: parameters) { (result: Result<BaseResponse<Directory>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let directory = response.data {
                    completion(.success(directory))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "创建目录失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getChatHistory(
        tenantId: String,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([ChatHistory], Int), NetworkError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "tenantId": tenantId,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getChatHistory) else {
            completion(.failure(.invalidURL))
            return
        }
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            do {
                // 解析外层 BaseResponse
                let baseResponse = try JSONDecoder().decode(BaseResponse<[ChatHistory]>.self, from: data)
                
                if baseResponse.isSuccess, let list = baseResponse.data {
                    var chatHistoryList = list
                    // 计算每条记录的时间差
                    for i in 0..<chatHistoryList.count {
                        chatHistoryList[i].calculateTimeAgo()
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success((chatHistoryList, baseResponse.total ?? 0)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: baseResponse.msg ?? "获取会话记录失败")))
                    }
                }
            } catch {
                print("❌ 解析失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }
    
    func getChatHistoryByChatId(chatId: String, completion: @escaping (Result<[ChatHistory], NetworkError>) -> Void) {
        let parameters: [String: Any] = ["chatId": chatId]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getChatHistoryByChatId) else {
            completion(.failure(.invalidURL))
            return
        }
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        print("🌐 请求URL: \(url)")
        print("📡 请求方法: GET")
        print("🔐 Authorization: \(TokenManager.shared.getAuthorizationHeader() ?? "无")")
        
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
            
            guard httpResponse.statusCode == 200 else {
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
            
            // 打印原始响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 原始响应数据:")
                print(jsonString)
            } else {
                print("📥 响应数据长度: \(data.count) bytes")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<[ChatHistory]>.self, from: data)
                print("✅ 数据解析成功，status: \(response.status), isSuccess: \(response.isSuccess)")
                if let msg = response.msg {
                    print("💬 服务器消息: \(msg)")
                }
                
                if response.isSuccess, let histories = response.data {
                    // 打印详细的会话记录数据
                    print("📋 会话记录详情（共 \(histories.count) 条）:")
                    for (index, history) in histories.enumerated() {
                        print("  第\(index + 1)条记录:")
                        print("    - id: \(history.id)")
                        print("    - chatId: \(history.chatId)")
                        print("    - prompt: \(history.prompt)")
                        print("    - thinkContent: \(history.thinkContent ?? "nil")")
                        print("    - responseContent: \(history.responseContent ?? "nil")")
                        print("    - createTime: \(history.createTime ?? "nil")")
                        print("    - updateTime: \(history.updateTime ?? "nil")")
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(histories))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取会话记录失败")))
                    }
                }
            } catch {
                print("❌ 数据解析失败: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ 原始数据: \(jsonString)")
                }
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    func uploadDoc(
        fileURL: URL,
        tenantId: String,
        directoryId: String,
        completion: @escaping (Result<String, NetworkError>) -> Void
    ) {
        // 构建 URL（替换路径参数）
        let urlPath = Constants.API.uploadDoc
            .replacingOccurrences(of: "{tenantId}", with: tenantId)
            .replacingOccurrences(of: "{directoryId}", with: directoryId)
        
        guard let url = URL(string: baseURL + urlPath) else {
            completion(.failure(.invalidURL))
            return
        }
        
        // 创建 multipart/form-data 请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 添加 Authorization header
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // 生成边界字符串
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建 multipart body
        var body = Data()
        
        // 添加文件数据
        do {
            let fileData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent
            let mimeType = getMimeType(for: filename)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        } catch {
            print("❌ 读取文件失败: \(error)")
            completion(.failure(.custom(message: "读取文件失败")))
            return
        }
        
        // 添加结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🌐 上传文档URL: \(url)")
        print("📁 文件名: \(fileURL.lastPathComponent)")
        print("🏢 租户ID: \(tenantId)")
        print("📂 目录ID: \(directoryId)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 上传网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            print("📊 上传响应状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            // 打印响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 上传响应数据: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<EmptyData>.self, from: data)
                
                if response.isSuccess {
                    DispatchQueue.main.async {
                        completion(.success(response.msg ?? "上传成功"))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "上传失败")))
                    }
                }
            } catch {
                print("❌ 解析上传响应失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 根据文件名获取 MIME 类型
    private func getMimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        case "txt":
            return "text/plain"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "md":
            return "text/markdown"
        default:
            return "application/octet-stream"
        }
    }

    /// 删除文档
    func deleteDoc(docId: String, completion: @escaping (Result<Int, NetworkError>) -> Void) {
        // 使用 APIEndpoint 枚举，传入 docId
        request(endpoint: .deleteDoc(docId)) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess {
                    if let deletedCount = response.data {
                        print("✅ 删除文档成功，删除数量: \(deletedCount)")
                        completion(.success(deletedCount))
                    } else {
                        print("⚠️ 删除文档响应中 data 字段为空")
                        completion(.failure(.custom(message: "响应数据格式错误")))
                    }
                } else {
                    let errorMsg = response.msg ?? "删除失败"
                    print("❌ 删除文档失败: \(errorMsg)")
                    completion(.failure(.custom(message: errorMsg)))
                }
            case .failure(let error):
                print("❌ 删除文档请求失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 用户信息相关方法

    /// 更新用户信息
    func updateUser(userData: UserData, completion: @escaping (Result<UserData, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "username": userData.username,
            "telephone": userData.telephone,
            "email": userData.email,
            "sex": userData.sex,
            "birthday": userData.birthday,
            "region": userData.region ?? "",
            "sign": userData.sign
        ]
        
        request(endpoint: .updateUser, method: "PUT", parameters: parameters) { (result: Result<BaseResponse<UserData>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let updatedUser = response.data {
                    completion(.success(updatedUser))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "更新用户信息失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 更新用户头像
    func updateAvatar(imageData: Data, completion: @escaping (Result<String, NetworkError>) -> Void) {
        // 构建 URL
        guard let url = URL(string: baseURL + Constants.API.updateAvater) else {
            completion(.failure(.invalidURL))
            return
        }
        
        // 创建 multipart/form-data 请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 添加 Authorization header
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // 生成边界字符串
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建 multipart body
        var body = Data()
        
        // 添加文件数据
        let filename = "avatar_\(Date().timeIntervalSince1970).jpg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🌐 上传头像URL: \(url)")
        print("📁 文件名: \(filename)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 上传头像网络错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(.custom(message: "无效的响应")))
                }
                return
            }
            
            print("📊 上传头像响应状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            
            // 打印响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 上传头像响应数据: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<StringData>.self, from: data)
                
                if response.isSuccess {
                    // 返回头像URL
                    let avatarUrl = response.data?.value ?? ""
                    DispatchQueue.main.async {
                        completion(.success(avatarUrl))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "上传头像失败")))
                    }
                }
            } catch {
                print("❌ 解析上传头像响应失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }
}

// 登录响应模型
struct LoginResponse {
    let userData: UserData
    let token: String
}
