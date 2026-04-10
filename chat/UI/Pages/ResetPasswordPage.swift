import SwiftUI

/// 重置密码页面
struct ResetPasswordPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    let email: String
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var isResetting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 表单校验
    private var isPasswordMatch: Bool {
        return newPassword == confirmPassword
    }
    
    private var isFormValid: Bool {
        return !newPassword.isEmpty &&
               !confirmPassword.isEmpty &&
               !verificationCode.isEmpty &&
               isPasswordMatch
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            customNavigationBar
            
            // 可滚动内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 白色背景圆角矩形表单
                    VStack(spacing: 0) {
                        // 新密码
                        formRow(
                            label: "新密码",
                            isRequired: true,
                            content: AnyView(
                                SecureField("请输入新密码", text: $newPassword)
                                    .font(.system(size: Dimens.normalFont))
                            )
                        )
                        
                        DividerLine()
                        
                        // 确认密码
                        formRow(
                            label: "确认密码",
                            isRequired: true,
                            content: AnyView(
                                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                                    SecureField("请再次输入新密码", text: $confirmPassword)
                                        .font(.system(size: Dimens.normalFont))
                                    
                                    if !isPasswordMatch && !confirmPassword.isEmpty {
                                        Text("两次输入的密码不一致")
                                            .font(.system(size: Dimens.normalFont - 2))
                                            .foregroundColor(Colors.warnColor)
                                    }
                                }
                            )
                        )
                        
                        DividerLine()
                        
                        // 验证码
                        formRow(
                            label: "验证码",
                            isRequired: true,
                            content: AnyView(
                                TextField("请输入验证码", text: $verificationCode)
                                    .font(.system(size: Dimens.normalFont))
                                    .keyboardType(.numberPad)
                            )
                        )
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.borderRadius)
                    
                    // 确定按钮
                    Button(action: handleResetPassword) {
                        HStack(spacing: Dimens.smallIcon) {
                            if isResetting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isResetting ? "重置中..." : "确定")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.whiteColor)
                        }
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(isFormValid && !isResetting ? Colors.primaryColor : Colors.grayColor)
                        .cornerRadius(Dimens.btnHeight / 2)
                    }
                    .disabled(!isFormValid || isResetting)
                    .padding(.bottom, Dimens.middleMargin)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
        }
        .background(Colors.pageBackgroundColor)
        .navigationBarHidden(true)  // 隐藏系统导航栏
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        // 使用全屏覆盖跳转到首页，确保不能返回
        .fullScreenCover(isPresented: $appState.isLoggedIn) {
            HomePage()
        }
    }
    
    // MARK: - 视图组件
    
    /// 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            // 标题
            Text("重置密码")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 占位按钮，保持标题居中
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    /// 分割线
    private func DividerLine() -> some View {
        Rectangle()
            .fill(Colors.grayColor.opacity(0.3))
            .frame(height: 1)
            .padding(.leading, Dimens.middleMargin)
    }
    
    /// 表单行视图
    private func formRow(label: String, isRequired: Bool, content: AnyView) -> some View {
        HStack(alignment: .center, spacing: Dimens.middleMargin) {
            // 标签
            HStack(spacing: 2) {
                if isRequired {
                    Text("*")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.warnColor)
                }
                Text(label)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
            }
            .frame(width: 80, alignment: .leading)
            
            // 表单内容
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
    
    // MARK: - 重置密码处理
    
    /// 处理重置密码
    private func handleResetPassword() {
        // 额外校验
        if !isPasswordMatch {
            alertMessage = "两次输入的密码不一致"
            showAlert = true
            return
        }
        
        if newPassword.count < 6 {
            alertMessage = "密码长度不能少于6位"
            showAlert = true
            return
        }
        
        isResetting = true
        
        HTTPClient.shared.resetPassword(email: email, password: newPassword, code: verificationCode) { result in
            DispatchQueue.main.async {
                self.isResetting = false
                
                switch result {
                case .success(let loginResponse):
                    // 保存用户信息和token
                    self.appState.updateUserData(loginResponse.userData)
                    self.appState.updateToken(loginResponse.token)
                    self.appState.isLoggedIn = true
                    
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    ResetPasswordPage(email: "test@example.com")
}
