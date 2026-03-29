import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var userData: UserData?
    @Published var token: String?
    @Published var isLoggedIn: Bool = false
    @Published var currentTenant: Tenant?  // 当前选中的租户
    @Published var currentModel: ChatModel?  // 当前选中的模型
    @Published var tenantList: [Tenant] = []  // 租户列表
    @Published var modelList: [ChatModel] = []  // 模型列表
    
    private let tenantIdKey = "current_tenant_id"
    private let modelIdKey = "current_model_id"
    
    private init() {
        // 从缓存加载token
        self.token = TokenManager.shared.getToken()
        self.isLoggedIn = token != nil
        
        // 从缓存加载租户ID和模型ID
        loadCachedTenantAndModel()
    }
    
    /// 从缓存加载租户和模型ID
    private func loadCachedTenantAndModel() {
        let tenantId = UserDefaults.standard.string(forKey: tenantIdKey)
        let modelId = UserDefaults.standard.string(forKey: modelIdKey)
        
        // 注意：实际的租户和模型对象需要在获取列表后根据ID匹配
        // 这里只保存ID，实际对象在获取列表后设置
        if let tenantId = tenantId {
            print("📦 从缓存加载租户ID: \(tenantId)")
        }
        if let modelId = modelId {
            print("📦 从缓存加载模型ID: \(modelId)")
        }
    }
    
    /// 保存当前租户到缓存
    func saveCurrentTenant(_ tenant: Tenant) {
        self.currentTenant = tenant
        UserDefaults.standard.set(tenant.id, forKey: tenantIdKey)
        print("💾 保存租户到缓存: \(tenant.name) (ID: \(tenant.id))")
    }
    
    /// 保存当前模型到缓存
    func saveCurrentModel(_ model: ChatModel) {
        self.currentModel = model
        UserDefaults.standard.set(model.id, forKey: modelIdKey)
        print("💾 保存模型到缓存: \(model.modelName) (ID: \(model.id))")
    }
    
    /// 获取缓存的租户ID
    func getCachedTenantId() -> String? {
        return UserDefaults.standard.string(forKey: tenantIdKey)
    }
    
    /// 获取缓存的模型ID
    func getCachedModelId() -> String? {
        return UserDefaults.standard.string(forKey: modelIdKey)
    }
    
    func updateUserData(_ userData: UserData) {
        self.userData = userData
    }
    
    func updateToken(_ token: String) {
        self.token = token
        TokenManager.shared.saveToken(token)
        self.isLoggedIn = true
    }
    
    func clearUserData() {
        self.userData = nil
        self.token = nil
        self.currentTenant = nil
        self.currentModel = nil
        self.tenantList = []
        self.modelList = []
        TokenManager.shared.clearToken()
        UserDefaults.standard.removeObject(forKey: tenantIdKey)
        UserDefaults.standard.removeObject(forKey: modelIdKey)
        self.isLoggedIn = false
    }
}
