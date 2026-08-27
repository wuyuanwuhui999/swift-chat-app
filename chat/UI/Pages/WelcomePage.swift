//
//  WelcomePage.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

struct WelcomePage: View {
    @ObservedObject private var appState = AppState.shared
    @State private var isCheckingLogin = true
    @State private var showLoginPage = false
    @State private var navigateToCompanyPage = false
    
    var body: some View {
        ZStack {
            Colors.pageBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 中间显示logo
                AIAvatar.large()
                
                // 正在校验登录态时显示加载指示（isCheckingLogin 之前是死状态，现消费之）
                if isCheckingLogin {
                    ProgressView()
                        .padding(.top, Dimens.middleMargin)
                        .tint(Colors.primaryColor)
                }
                
                Spacer()
            }
        }
        .onAppear {
            checkLoginStatus()
        }
        .fullScreenCover(isPresented: $showLoginPage) {
            LoginPage()
        }
        .fullScreenCover(isPresented: $navigateToCompanyPage) {
            CompanyPage()
        }
    }
    
    /// 检查登录状态
    private func checkLoginStatus() {
        // 检查token是否存在（只需判断存在性，不取用 token 值）
        if TokenManager.shared.getToken() != nil {
            // 有token，调用getUserData接口
            HTTPClient.shared.getUserData { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let userData):
                        // 保存用户信息到全局
                        AppState.shared.updateUserData(userData)
                        AppState.shared.isLoggedIn = true
                        // 跳转到 CompanyPage
                        self.navigateToCompanyPage = true
                    case .failure(let error):
                        print("获取用户信息失败: \(error.localizedDescription)")
                        AppState.shared.isLoggedIn = false
                        // 显示登录页
                        self.showLoginPage = true
                    }
                    isCheckingLogin = false
                }
            }
        } else {
            // 没有token，显示登录页
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isCheckingLogin = false
                AppState.shared.isLoggedIn = false
                showLoginPage = true
            }
        }
    }
}

#Preview {
    WelcomePage()
}