import Foundation
import SwiftUI
import Combine  // 新增：导入 Combine 框架

/// WebSocket 连接管理器
class WebSocketManager: NSObject, ObservableObject {
    static let shared = WebSocketManager()
        
    // MARK: - Published Properties
    @Published var isReceiving = false // 是否正在接收消息
    @Published var currentResponse = "" // 当前接收的响应内容
    
    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var onMessageReceived: ((String) -> Void)?
    private var onComplete: (() -> Void)?

    // 修复：将 private init() 改为 override init() 以满足 ObservableObject 协议
    override init() {
        super.init()
        // 初始化代码
    }
    
    /// 连接 WebSocket
    func connect(
        modelId: String,
        chatId: String,
        tenantId: String,
        prompt: String,
        showThink: Bool,
        language: String,
        docIds: [String] = [],  // 新增：文档ID列表
        type: String = "",      // 新增：类型（document 等）
        onMessage: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onMessageReceived = onMessage
        self.onComplete = onComplete
        self.isReceiving = true
        self.currentResponse = ""
        
        // 1. 检查 Token
        guard let token = TokenManager.shared.getToken() else {
            print("❌ 未找到 token")
            onComplete()
            return
        }
        
        // 2. 构建 URL
        let urlString = "\(Constants.webSocketURL)?token=Bearer \(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else {
            print("❌ 无效的 WebSocket URL: \(urlString)")
            onComplete()
            return
        }
        
        // 3. 建立连接
        var request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 4. 发送消息
        sendMessage(
            modelId: modelId,
            chatId: chatId,
            tenantId: tenantId,
            prompt: prompt,
            showThink: showThink,
            language: language,
            docIds: docIds,
            type: type
        )
        
        // 5. 开始接收消息
        receiveMessage()
    }

    // 修改 sendMessage 方法，添加 docIds 和 type 参数
    private func sendMessage(
        modelId: String,
        chatId: String,
        tenantId: String,
        prompt: String,
        showThink: Bool,
        language: String,
        docIds: [String] = [],
        type: String = ""
    ) {
        let message: [String: Any] = [
            "modelId": modelId,
            "chatId": chatId,
            "tenantId": tenantId,
            "type": type,
            "docIds": docIds,
            "prompt": prompt,
            "systemPrompt": Constants.systemPrompt,
            "showThink": showThink,
            "language": language
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            print("📤 WebSocket发送消息: \(jsonString)")
            webSocketTask?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ 发送消息失败: \(error)")
                    DispatchQueue.main.async {
                        self.isReceiving = false
                        self.onComplete?()
                    }
                } else {
                    print("✅ 消息已发送")
                }
            }
        } catch {
            print("❌ 序列化消息失败: \(error)")
            DispatchQueue.main.async {
                self.isReceiving = false
                self.onComplete?()
            }
        }
    }
    
    /// 接收消息 (递归调用以持续监听)
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleReceivedText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleReceivedText(text)
                    }
                @unknown default:
                    break
                }
                
                // 只有在接收中且连接有效时，才继续接收下一条
                if self.isReceiving {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("❌ 接收消息失败: \(error)")
                self.disconnect()
                DispatchQueue.main.async {
                    self.isReceiving = false
                    self.onComplete?()
                }
            }
        }
    }
    
    /// 处理接收到的文本
    private func handleReceivedText(_ text: String) {
        DispatchQueue.main.async {
            // 检查结束标记
            if text.contains("[completed]") || text.contains("[done]") {
                print("✅ 消息接收完成")
                self.disconnect()
                self.isReceiving = false
                self.onComplete?()
                return
            }
            
            // 流式更新：追加内容
            self.currentResponse += text
            self.onMessageReceived?(text)
        }
    }
    
    /// 关闭连接
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    /// 重置状态 (用于清空聊天)
    func reset() {
        disconnect()
        isReceiving = false
        currentResponse = ""
    }
}
