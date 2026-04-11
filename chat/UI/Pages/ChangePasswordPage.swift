import SwiftUI

/// 修改密码页面
struct ChangePasswordPage: View {
    @Environment(\.dismiss) private var dismiss
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 表单校验
    private var isPasswordMatch: Bool {
        return newPassword == confirmPassword
    }
    
    private var isFormValid: Bool {
        return !oldPassword.isEmpty &&
               !newPassword.isEmpty &&
               !confirmPassword.isEmpty &&
               isPasswordMatch &&
               newPassword.count >= 6
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
                        // 旧密码
                        formRow(
                            label: "旧密码",
                            isRequired: true,
                            content: AnyView(
                                SecureField("请输入旧密码", text: $oldPassword)
                                    .font(.system(size: Dimens.normalFont))
                            )
                        )
                        
                        DividerLine()
                        
                        // 新密码
                        formRow(
                            label: "新密码",
                            isRequired: true,
                            content: AnyView(
                                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                                    SecureField("请输入新密码", text: $newPassword)
                                        .font(.system(size: Dimens.normalFont))
                                    
                                    if !newPassword.isEmpty && newPassword.count < 6 {
                                        Text("密码长度不能少于6位")
                                            .font(.system(size: Dimens.normalFont - 2))
                                            .foregroundColor(Colors.warnColor)
                                    }
                                }
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
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.borderRadius)
                    
                    // 确定按钮
                    Button(action: handleUpdatePassword) {
                        HStack(spacing: Dimens.smallIcon) {
                            if isUpdating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isUpdating ? "修改中..." : "确定")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.whiteColor)
                        }
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(isFormValid && !isUpdating ? Colors.primaryColor : Colors.grayColor)
                        .cornerRadius(Dimens.btnHeight / 2)
                    }
                    .disabled(!isFormValid || isUpdating)
                    .padding(.bottom, Dimens.middleMargin)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
        }
        .background(Colors.pageBackgroundColor)
        .navigationBarHidden(true)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {
                if alertMessage.contains("成功") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
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
            Text("修改密码")
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
    
    // MARK: - 修改密码处理
    
    /// 处理修改密码
    private func handleUpdatePassword() {
        // 额外校验
        if newPassword.count < 6 {
            alertMessage = "新密码长度不能少于6位"
            showAlert = true
            return
        }
        
        if !isPasswordMatch {
            alertMessage = "两次输入的新密码不一致"
            showAlert = true
            return
        }
        
        if oldPassword == newPassword {
            alertMessage = "新密码不能与旧密码相同"
            showAlert = true
            return
        }
        
        isUpdating = true
        
        HTTPClient.shared.updatePassword(oldPassword: oldPassword, newPassword: newPassword) { result in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                switch result {
                case .success(let data):
                    if data == 1 {
                        self.alertMessage = "密码修改成功"
                        self.showAlert = true
                    } else {
                        self.alertMessage = "密码修改失败，请检查旧密码是否正确"
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
    ChangePasswordPage()
}
