import SwiftUI

/// 忘记密码页面
struct ForgetPasswordPage: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isSending = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToReset = false
    
    // 邮箱格式校验
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 自定义导航栏
                customNavigationBar
                
                // 可滚动内容区域
                ScrollView {
                    VStack(spacing: Dimens.middleMargin) {
                        // 白色背景圆角矩形表单
                        VStack(spacing: 0) {
                            // 邮箱
                            formRow(
                                label: "邮箱",
                                isRequired: true,
                                content: AnyView(
                                    TextField("请输入注册邮箱", text: $email)
                                        .font(.system(size: Dimens.normalFont))
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                )
                            )
                        }
                        .background(Colors.whiteColor)
                        .cornerRadius(Dimens.borderRadius)
                        
                        // 提交按钮
                        Button(action: handleSubmit) {
                            HStack(spacing: Dimens.smallIcon) {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isSending ? "发送中..." : "提交")
                                    .font(.system(size: Dimens.normalFont))
                                    .foregroundColor(Colors.whiteColor)
                            }
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(isEmailValid && !isSending ? Colors.primaryColor : Colors.grayColor)
                            .cornerRadius(Dimens.btnHeight / 2)
                        }
                        .disabled(!isEmailValid || isSending)
                        .padding(.bottom, Dimens.middleMargin)
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.top, Dimens.middleMargin)
                }
                .background(Colors.pageBackgroundColor)
            }
            .background(Colors.pageBackgroundColor)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $navigateToReset) {
                ResetPasswordPage(email: email)
            }
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
            Text("忘记密码")
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
    
    // MARK: - 提交处理
    
    /// 处理提交
    private func handleSubmit() {
        isSending = true
        
        HTTPClient.shared.sendEmailVerificationCode(email: email) { result in
            DispatchQueue.main.async {
                self.isSending = false
                
                switch result {
                case .success(let response):
                    if response.isSuccess {
                        self.alertMessage = "验证码已发送到您的邮箱"
                        self.showAlert = true
                        // 延迟跳转，让用户看到提示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.navigateToReset = true
                        }
                    } else {
                        self.alertMessage = response.msg ?? "发送验证码失败"
                        self.showAlert = true
                    }
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    ForgetPasswordPage()
}
