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
    // HTTPClient.swift - 修改 request 方法

    // 通用请求方法
    func request<T: Codable>(
        endpoint: APIEndpoint,
        method: String? = nil,
        parameters: [String: Any]? = nil,
        completion: @escaping (Result<BaseResponse<T>, NetworkError>) -> Void
    ) {
        // 获取基础 URL
        guard var urlComponents = URLComponents(string: baseURL + endpoint.path) else {
            print("❌ 无效的URL")
            completion(.failure(.invalidURL))
            return
        }
        
        let httpMethod = method ?? endpoint.method
        
        // 如果是 GET 方法且有参数，将参数拼接到 URL 查询字符串
        if httpMethod == "GET" || httpMethod == "DELETE" {
            if let parameters = parameters, !parameters.isEmpty {
                var queryItems: [URLQueryItem] = []
                for (key, value) in parameters {
                    queryItems.append(URLQueryItem(name: key, value: "\(value)"))
                }
                urlComponents.queryItems = queryItems
            }
        }
        
        guard let url = urlComponents.url else {
            print("❌ 构建URL失败")
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加Authorization header
        if let authHeader = TokenManager.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        // 仅对非 GET/DELETE 方法添加请求参数到 body
        if httpMethod != "GET" && httpMethod != "DELETE" {
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
        }
        
        print("🌐 请求URL: \(url)")
        
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
        
        request(endpoint: .login, parameters: parameters) { (result: Result<BaseResponse<User>, NetworkError>) in
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
    func getUserData(completion: @escaping (Result<User, NetworkError>) -> Void) {
        request(endpoint: .getUserData) { (result: Result<BaseResponse<User>, NetworkError>) in
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
        
        request(endpoint: .loginByEmail, parameters: parameters) { (result: Result<BaseResponse<User>, NetworkError>) in
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
    func getTenantList(companyId: String? = nil, completion: @escaping (Result<[Tenant], NetworkError>) -> Void) {
        // 构建带参数的URL
        var parameters: [String: Any] = [:]
        if let companyId = companyId, !companyId.isEmpty {
            parameters["companyId"] = companyId
        }
        request(endpoint: .getTenantList, parameters: parameters) { (result: Result<BaseResponse<[Tenant]>, NetworkError>) in
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
    /// - Parameters:
    ///   - companyId: 公司ID（必传参数）
    ///   - completion: 完成回调
    func getModelList(companyId: String, completion: @escaping (Result<[ChatModel], NetworkError>) -> Void) {
        // companyId 是必传参数，不能为空
        guard !companyId.isEmpty else {
            completion(.failure(.custom(message: "companyId 不能为空")))
            return
        }
        
        // 直接使用 request 方法，传入 endpoint 和 parameters
        // 由于 getModelList 的 endpoint 已经包含了 companyId 的处理，
        // 但为了统一，我们通过 parameters 传递 companyId，让 request 方法处理
        let parameters: [String: Any] = ["companyId": companyId]
        
        request(endpoint: .getModelList(companyId), parameters: parameters) { (result: Result<BaseResponse<[ChatModel]>, NetworkError>) in
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
    func updateUser(userData: User, completion: @escaping (Result<User, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "username": userData.username,
            "telephone": userData.telephone,
            "email": userData.email,
            "sex": userData.sex,
            "birthday": userData.birthday,
            "region": userData.region ?? "",
            "sign": userData.sign
        ]
        
        request(endpoint: .updateUser, method: "PUT", parameters: parameters) { (result: Result<BaseResponse<User>, NetworkError>) in
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
    
    // MARK: - 注册相关方法

    /// 校验账号是否已存在
    func vertifyUser(userAccount: String, completion: @escaping (Result<Int, NetworkError>) -> Void) {
        let parameters: [String: Any] = ["userAccount": userAccount]
        
        request(endpoint: .vertifyUser, parameters: parameters) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let data = response.data {
                    completion(.success(data))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "校验账号失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 注册新用户
    func register(userData: User, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "userAccount": userData.userAccount,
            "password": userData.password?.md5 ?? "",
            "username": userData.username,
            "telephone": userData.telephone,
            "email": userData.email,
            "sex": userData.sex,
            "birthday": userData.birthday ?? "",
            "region": userData.region ?? "",
            "sign": userData.sign
        ]
        
        request(endpoint: .register, parameters: parameters) { (result: Result<BaseResponse<User>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let userData = response.data, let token = response.token {
                    let loginResponse = LoginResponse(userData: userData, token: token)
                    completion(.success(loginResponse))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "注册失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 重置密码相关方法

    /// 重置密码
    func resetPassword(email: String, password: String, code: String, completion: @escaping (Result<LoginResponse, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "email": email,
            "password": password.md5,
            "code": code
        ]
        
        request(endpoint: .resetPassword, parameters: parameters) { (result: Result<BaseResponse<User>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let userData = response.data, let token = response.token {
                    let loginResponse = LoginResponse(userData: userData, token: token)
                    completion(.success(loginResponse))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "重置密码失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 修改密码相关方法

    /// 修改密码
    func updatePassword(oldPassword: String, newPassword: String, completion: @escaping (Result<Int, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "oldPassword": oldPassword.md5,
            "newPassword": newPassword.md5
        ]
        
        request(endpoint: .updatePassword, parameters: parameters) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let data = response.data {
                    completion(.success(data))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "修改密码失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 提示词相关方法

    /// 获取用户提示词
    func getPrompt(tenantId: String, completion: @escaping (Result<Prompt, NetworkError>) -> Void) {
        let parameters: [String: Any] = ["tenantId": tenantId]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getPrompt) else {
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
        
        print("🌐 获取提示词URL: \(url)")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 获取提示词网络错误: \(error.localizedDescription)")
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
                let response = try decoder.decode(BaseResponse<Prompt>.self, from: data)
                
                if response.isSuccess, let prompt = response.data {
                    DispatchQueue.main.async {
                        completion(.success(prompt))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取提示词失败")))
                    }
                }
            } catch {
                print("❌ 解析提示词响应失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - 提示词相关方法

    /// 更新提示词
    func updatePrompt(prompt: Prompt, completion: @escaping (Result<Prompt, NetworkError>) -> Void) {
        let parameters: [String: Any] = [
            "id": prompt.id,
            "tenantId": prompt.tenantId,
            "userId": prompt.userId
        ]
        
        request(endpoint: .updatePrompt, parameters: parameters) { (result: Result<BaseResponse<Prompt>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let updatedPrompt = response.data {
                    completion(.success(updatedPrompt))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "更新提示词失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取公司列表
    func getCompanyList(completion: @escaping (Result<[Company], NetworkError>) -> Void) {
        request(endpoint: .getCompanyList) { (result: Result<BaseResponse<[Company]>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let companies = response.data {
                    completion(.success(companies))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "获取公司列表失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 租户用户管理相关方法
    
    /// 获取当前用户在当前租户内的信息
    /// - Parameters:
    ///   - tenantId: 租户ID
    ///   - completion: 完成回调
    func getTenantUser(tenantId: String, completion: @escaping (Result<TenantUser, NetworkError>) -> Void) {
        let parameters: [String: Any] = ["tenantId": tenantId]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getTenantUser) else {
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
        
        print("🌐 获取租户用户信息URL: \(url)")
        
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
            
            // 打印原始响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 租户用户信息原始响应: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<TenantUser>.self, from: data)
                
                if response.isSuccess, let tenantUser = response.data {
                    DispatchQueue.main.async {
                        completion(.success(tenantUser))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取租户用户信息失败")))
                    }
                }
            } catch {
                print("❌ 解析租户用户信息失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 获取租户下的用户列表（支持关键词搜索）
    /// - Parameters:
    ///   - tenantId: 租户ID
    ///   - keyword: 搜索关键词（可选）
    ///   - pageNum: 页码
    ///   - pageSize: 每页大小
    ///   - completion: 完成回调
    func getTenantUserList(
        tenantId: String,
        keyword: String? = nil,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([TenantUser], Int), NetworkError>) -> Void
    ) {
        var parameters: [String: Any] = [
            "tenantId": tenantId,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        // 如果有搜索关键词，添加到参数中
        if let keyword = keyword, !keyword.isEmpty {
            parameters["keyword"] = keyword
        }
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getTenantUserList) else {
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
        
        print("🌐 获取租户用户列表URL: \(url)")
        
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
            
            // 打印原始响应数据以便调试
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 租户用户列表原始响应: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<[TenantUser]>.self, from: data)
                
                if response.isSuccess, let users = response.data {
                    DispatchQueue.main.async {
                        completion(.success((users, response.total ?? 0)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取租户用户列表失败")))
                    }
                }
            } catch {
                print("❌ 解析租户用户列表失败: \(error)")
                // 尝试打印更详细的解析错误信息
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   - 缺少字段: \(key.stringValue), 路径: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   - 值为空: \(type), 路径: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   - 类型不匹配: \(type), 路径: \(context.codingPath)")
                    default:
                        print("   - 其他错误: \(decodingError)")
                    }
                }
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    // MARK: - 搜索公司用户（支持分页）

    /// 搜索公司用户（支持分页）
    /// - Parameters:
    ///   - keyword: 搜索关键词（姓名或工号）
    ///   - companyId: 公司ID
    ///   - pageNum: 页码
    ///   - pageSize: 每页大小
    ///   - completion: 完成回调，返回用户列表和总数
    func searchCompanyUsers(
        keyword: String,
        companyId: String,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([SearchUserResult], Int), NetworkError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "keyword": keyword,
            "companyId": companyId,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        // 使用封装好的 request 方法
        request(endpoint: .searchCompanyUsers, parameters: parameters) { (result: Result<BaseResponse<[SearchUserResult]>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let users = response.data {
                    completion(.success((users, response.total ?? 0)))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "搜索失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 添加用户到租户
    /// - Parameters:
    ///   - tenantId: 租户ID
    ///   - userId: 用户ID
    ///   - completion: 完成回调（返回data大于0表示成功）
    func addTenantUser(tenantId: String, userId: String, completion: @escaping (Result<Int, NetworkError>) -> Void) {
        // POST 请求，不需要 body 参数，所有参数都在 URL 路径中
        let parameters: [String: Any] = [:]
        
        request(endpoint: .addTenantUser(tenantId, userId), parameters: parameters) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let data = response.data {
                    completion(.success(data))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "添加用户到租户失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 管理员管理相关方法

    /// 设为管理员
    func addAdmin(tenantId: String, userId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        request(endpoint: .addAdmin(tenantId, userId)) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let data = response.data {
                    completion(.success(data > 0))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "操作失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 取消管理员
    func cancelAdmin(tenantId: String, userId: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        request(endpoint: .cancelAdmin(tenantId, userId)) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let data = response.data {
                    completion(.success(data > 0))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "操作失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }    

    /// 搜索公司用户（支持分页）
    func searchCompanyUsers(
        keyword: String,
        companyId: String,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([User], Int), NetworkError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "keyword": keyword,
            "companyId": companyId,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.searchCompanyUsers) else {
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
                let response = try decoder.decode(BaseResponse<[User]>.self, from: data)
                
                if response.isSuccess, let users = response.data {
                    DispatchQueue.main.async {
                        completion(.success((users, response.total ?? 0)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "搜索失败")))
                    }
                }
            } catch {
                print("❌ 解析搜索公司用户响应失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 添加用户到公司
    /// - Parameters:
    ///   - companyId: 公司ID
    ///   - userId: 用户ID
    ///   - role: 角色 (0: 普通用户, 1: 管理员)
    ///   - positionId: 职位ID（可选）
    ///   - completion: 完成回调，返回 data > 0 表示成功
    func addCompanyUser(
        companyId: String,
        userId: String,
        role: Int,
        positionId: String?,
        completion: @escaping (Result<Int, NetworkError>) -> Void
    ) {
        var parameters: [String: Any] = [
            "userId": userId,
            "companyId": companyId,
            "role": role
        ]
        
        if let positionId = positionId, !positionId.isEmpty {
            parameters["positionId"] = positionId
        }
        
        print("🌐 添加用户请求参数: \(parameters)")
        
        request(endpoint: .addCompanyUser, parameters: parameters) { (result: Result<BaseResponse<Int>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess {
                    if let data = response.data {
                        print("✅ 添加用户成功，返回数据: \(data)")
                        completion(.success(data))
                    } else {
                        print("⚠️ 添加用户响应中 data 字段为空")
                        completion(.success(0))
                    }
                } else {
                    print("❌ 添加用户失败: \(response.msg ?? "未知错误")")
                    completion(.failure(.custom(message: response.msg ?? "添加用户失败")))
                }
            case .failure(let error):
                print("❌ 添加用户请求失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - 公司用户管理相关方法

    /// 获取公司用户列表
    /// - Parameters:
    ///   - companyId: 公司ID
    ///   - keyword: 搜索关键词（可选）
    ///   - pageNum: 页码
    ///   - pageSize: 每页大小
    ///   - completion: 完成回调
    func getCompanyUsers(
        companyId: String,
        keyword: String? = nil,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([CompanyUser], Int), NetworkError>) -> Void
    ) {
        var parameters: [String: Any] = [
            "companyId": companyId,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        if let keyword = keyword, !keyword.isEmpty {
            parameters["keyword"] = keyword
        }
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getCompanyUsers) else {
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
        
        print("🌐 获取公司用户列表URL: \(url)")
        
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
            
            // 打印原始响应数据
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 公司用户列表响应: \(jsonString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(BaseResponse<[CompanyUser]>.self, from: data)
                
                if response.isSuccess, let users = response.data {
                    DispatchQueue.main.async {
                        completion(.success((users, response.total ?? 0)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取公司用户列表失败")))
                    }
                }
            } catch {
                print("❌ 解析公司用户列表失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    // MARK: - 部门/职位相关方法

    /// 获取部门列表
    func getDepartments(companyId: String, completion: @escaping (Result<[Department], NetworkError>) -> Void) {
        let parameters: [String: Any] = ["companyId": companyId]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getDepartments) else {
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
        
        print("🌐 获取部门列表URL: \(url)")
        
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
                let response = try decoder.decode(BaseResponse<[Department]>.self, from: data)
                
                if response.isSuccess, let departments = response.data {
                    DispatchQueue.main.async {
                        completion(.success(departments))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取部门列表失败")))
                    }
                }
            } catch {
                print("❌ 解析部门列表失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }

    /// 获取职位列表
    func getPositions(departmentId: String, completion: @escaping (Result<[Position], NetworkError>) -> Void) {
        let parameters: [String: Any] = ["departmentId": departmentId]
        
        guard var urlComponents = URLComponents(string: baseURL + Constants.API.getPositions) else {
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
        
        print("🌐 获取职位列表URL: \(url)")
        
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
                let response = try decoder.decode(BaseResponse<[Position]>.self, from: data)
                
                if response.isSuccess, let positions = response.data {
                    DispatchQueue.main.async {
                        completion(.success(positions))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.custom(message: response.msg ?? "获取职位列表失败")))
                    }
                }
            } catch {
                print("❌ 解析职位列表失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError))
                }
            }
        }
        
        task.resume()
    }
    
    /// 搜索租户用户
    /// - Parameters:
    ///   - tenantId: 租户ID
    ///   - companyId: 公司ID
    ///   - keyword: 搜索关键词（姓名或工号）
    ///   - pageNum: 页码
    ///   - pageSize: 每页大小
    ///   - completion: 完成回调
    func searchTenantUsers(
        tenantId: String,
        companyId: String,
        keyword: String,
        pageNum: Int,
        pageSize: Int,
        completion: @escaping (Result<([SearchUserResult], Int), NetworkError>) -> Void
    ) {
        let parameters: [String: Any] = [
            "tenantId": tenantId,
            "companyId": companyId,
            "keyword": keyword,
            "pageNum": pageNum,
            "pageSize": pageSize
        ]
        
        request(endpoint: .searchTenantUsers, parameters: parameters) { (result: Result<BaseResponse<[SearchUserResult]>, NetworkError>) in
            switch result {
            case .success(let response):
                if response.isSuccess, let users = response.data {
                    completion(.success((users, response.total ?? 0)))
                } else {
                    completion(.failure(.custom(message: response.msg ?? "搜索租户用户失败")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// 登录响应模型
struct LoginResponse {
    let userData: User
    let token: String
}
