//
//  LoginPage.swift
//  chat
//
//  Created by 吴文强 on 2026/3/27.
//
// UI/Pages/LoginPage.swift
import SwiftUI

struct LoginPage: View {
    @ObservedObject private var appState = AppState.shared
    @State private var account = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var isLoginButtonEnabled: Bool {
        !account.isEmpty && !password.isEmpty && !isLoggingIn
    }
    
    var body: some View {
        ZStack {
            Colors.pageBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 顶部logo
                if let logoImage = UIImage(named: "logo") {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Dimens.bigIcon, height: Dimens.bigIcon)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Dimens.bigIcon, height: Dimens.bigIcon)
                        .foregroundColor(.themePrimary)
                }
                
                Spacer()
                    .frame(height: Dimens.middleMargin * 2)
                
                // 登录面板
                VStack(spacing: Dimens.middleMargin * 2) {
                    // 账号输入框
                    CustomTextField(
                        text: $account,
                        placeholder: "请输入账号",
                        isSecure: false
                    )
                    
                    // 密码输入框
                    CustomTextField(
                        text: $password,
                        placeholder: "请输入密码",
                        isSecure: true
                    )
                    
                    // 登录按钮
                    Button(action: handleLogin) {
                        Text("登录")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.themeWhite)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(isLoginButtonEnabled ? Colors.primaryColor : Colors.grayColor)
                            .cornerRadius(Dimens.btnHeight)
                    }
                    .disabled(!isLoginButtonEnabled)
                    
                    // 注册按钮
                    Button(action: handleRegister) {
                        Text("注册")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.themeGray)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight)
                                    .stroke(Colors.grayColor, lineWidth: 1)
                            )
                    }
                    
                    // 忘记密码按钮
                    Button(action: handleForgotPassword) {
                        Text("忘记密码？")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.themeGray)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(Dimens.middleMargin)
                .background(Color.themeWhite)
                .cornerRadius(Dimens.borderRadius)
                .padding(.horizontal, Dimens.middleMargin)
                
                Spacer()
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleLogin() {
        isLoggingIn = true
        
        HTTPClient.shared.login(userAccount: account, password: password) { result in
            DispatchQueue.main.async {
                isLoggingIn = false
                
                switch result {
                case .success(let loginResponse):
                    // 保存用户信息和token
                    appState.updateUserData(loginResponse.userData)
                    appState.updateToken(loginResponse.token)
                    appState.isLoggedIn = true
                    
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    private func handleRegister() {
        // 预留注册功能
        print("注册按钮点击 - 待实现")
    }
    
    private func handleForgotPassword() {
        // 预留忘记密码功能
        print("忘记密码按钮点击 - 待实现")
    }
}

// 自定义输入框组件
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .autocapitalization(.none)
            }
        }
        .font(.system(size: Dimens.normalFont))
        .padding(.horizontal, Dimens.middleMargin)
        .frame(height: Dimens.inputHeight)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                .stroke(isFocused ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
        )
    }
}

#Preview {
    LoginPage()
}
