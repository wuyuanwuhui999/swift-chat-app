//
//  AppState.swift
//  chat
//
//  Created by 吴文强 on 2026/3/27.
//

// Models/AppState.swift
import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var userData: UserData?
    @Published var token: String?
    @Published var isLoggedIn: Bool = false
    
    private init() {
        // 从缓存加载token
        self.token = TokenManager.shared.getToken()
        self.isLoggedIn = token != nil
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
        TokenManager.shared.clearToken()
        self.isLoggedIn = false
    }
}
