import SwiftUI

/// 注册页面
struct RegisterPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isRegistering = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 表单字段
    @State private var userAccount = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var telephone = ""
    @State private var email = ""
    @State private var selectedGender = 0
    @State private var birthday = Date()
    @State private var region = ""
    @State private var sign = ""
    
    // 账号校验相关
    @State private var isVerifyingAccount = false
    @State private var accountVerified = false
    @State private var accountExists = false
    @State private var verifyWorkItem: DispatchWorkItem?
    
    // 表单校验状态
    @State private var isPhoneValid = true
    @State private var isEmailValid = true
    @State private var isPasswordMatch = true
    
    // 性别选项
    private let genderOptions = ["男", "女"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            customNavigationBar
            
            // 可滚动内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 白色背景圆角矩形表单
                    VStack(spacing: 0) {
                        // 帐号
                        formRow(
                            label: "帐号",
                            isRequired: true,
                            content: AnyView(
                                TextField("请输入帐号", text: $userAccount)
                                    .font(.system(size: Dimens.normalFont))
                                    .autocapitalization(.none)
                                    .onChange(of: userAccount) { newValue in
                                        handleAccountChange(newValue)
                                    }
                                    .overlay(
                                        HStack {
                                            Spacer()
                                            if isVerifyingAccount {
                                                ProgressView()
                                                    .frame(width: Dimens.smallIcon, height: Dimens.smallIcon)
                                            } else if !userAccount.isEmpty && accountVerified {
                                                Image(systemName: accountExists ? "xmark.circle.fill" : "checkmark.circle.fill")
                                                    .foregroundColor(accountExists ? Colors.warnColor : .green)
                                                    .font(.system(size: Dimens.smallIcon))
                                            }
                                        }
                                    )
                            )
                        )
                        
                        DividerLine()
                        
                        // 密码
                        formRow(
                            label: "密码",
                            isRequired: true,
                            content: AnyView(
                                SecureField("请输入密码", text: $password)
                                    .font(.system(size: Dimens.normalFont))
                                    .onChange(of: password) { _ in
                                        validatePasswordMatch()
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
                                    SecureField("请再次输入密码", text: $confirmPassword)
                                        .font(.system(size: Dimens.normalFont))
                                        .onChange(of: confirmPassword) { _ in
                                            validatePasswordMatch()
                                        }
                                    
                                    if !isPasswordMatch && !confirmPassword.isEmpty {
                                        Text("两次输入的密码不一致")
                                            .font(.system(size: Dimens.normalFont - 2))
                                            .foregroundColor(Colors.warnColor)
                                    }
                                }
                            )
                        )
                        
                        DividerLine()
                        
                        // 昵称
                        formRow(
                            label: "昵称",
                            isRequired: true,
                            content: AnyView(
                                TextField("请输入昵称", text: $username)
                                    .font(.system(size: Dimens.normalFont))
                            )
                        )
                        
                        DividerLine()
                        
                        // 电话
                        formRow(
                            label: "电话",
                            isRequired: false,
                            content: AnyView(
                                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                                    TextField("请输入电话号码", text: $telephone)
                                        .font(.system(size: Dimens.normalFont))
                                        .keyboardType(.phonePad)
                                        .onChange(of: telephone) { _ in
                                            validatePhone()
                                        }
                                    
                                    if !isPhoneValid && !telephone.isEmpty {
                                        Text("请输入正确的手机号码")
                                            .font(.system(size: Dimens.normalFont - 2))
                                            .foregroundColor(Colors.warnColor)
                                    }
                                }
                            )
                        )
                        
                        DividerLine()
                        
                        // 邮箱
                        formRow(
                            label: "邮箱",
                            isRequired: true,
                            content: AnyView(
                                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                                    TextField("请输入邮箱", text: $email)
                                        .font(.system(size: Dimens.normalFont))
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .onChange(of: email) { _ in
                                            validateEmail()
                                        }
                                    
                                    if !isEmailValid && !email.isEmpty {
                                        Text("请输入正确的邮箱地址")
                                            .font(.system(size: Dimens.normalFont - 2))
                                            .foregroundColor(Colors.warnColor)
                                    }
                                }
                            )
                        )
                        
                        DividerLine()
                        
                        // 性别
                        formRow(
                            label: "性别",
                            isRequired: false,
                            content: AnyView(
                                HStack {
                                    ForEach(0..<genderOptions.count, id: \.self) { index in
                                        Button(action: {
                                            selectedGender = index
                                        }) {
                                            HStack(spacing: Dimens.smallIcon) {
                                                Image(systemName: selectedGender == index ? "largecircle.fill.circle" : "circle")
                                                    .foregroundColor(selectedGender == index ? Colors.primaryColor : Colors.grayColor)
                                                Text(genderOptions[index])
                                                    .font(.system(size: Dimens.normalFont))
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if index < genderOptions.count - 1 {
                                            Spacer()
                                        }
                                    }
                                }
                            )
                        )
                        
                        DividerLine()
                        
                        // 出生日期
                        formRow(
                            label: "出生日期",
                            isRequired: false,
                            content: AnyView(
                                DatePicker("", selection: $birthday, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            )
                        )
                        
                        DividerLine()
                        
                        // 地区
                        formRow(
                            label: "地区",
                            isRequired: false,
                            content: AnyView(
                                TextField("请输入地区", text: $region)
                                    .font(.system(size: Dimens.normalFont))
                            )
                        )
                        
                        DividerLine()
                        
                        // 个性签名
                        formRow(
                            label: "个性签名",
                            isRequired: false,
                            content: AnyView(
                                TextField("请输入个性签名", text: $sign)
                                    .font(.system(size: Dimens.normalFont))
                            )
                        )
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.borderRadius)
                    
                    // 注册按钮
                    Button(action: handleRegister) {
                        HStack(spacing: Dimens.smallIcon) {
                            if isRegistering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isRegistering ? "注册中..." : "注册")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.whiteColor)
                        }
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(isFormValid ? Colors.primaryColor : Colors.grayColor)
                        .cornerRadius(Dimens.btnHeight / 2)
                    }
                    .disabled(!isFormValid || isRegistering)
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
            Text("注册")
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
    
    // MARK: - 表单校验
    
    /// 表单是否有效
    private var isFormValid: Bool {
        return !userAccount.isEmpty &&
               !password.isEmpty &&
               !confirmPassword.isEmpty &&
               !username.isEmpty &&
               !email.isEmpty &&
               isPasswordMatch &&
               isPhoneValid &&
               isEmailValid &&
               accountVerified &&
               !accountExists
    }
    
    /// 处理账号变化（延时1秒校验）
    /// 处理账号变化（延时1秒校验）
    private func handleAccountChange(_ newValue: String) {
        // 取消之前的任务
        verifyWorkItem?.cancel()
        
        guard !newValue.isEmpty else {
            accountVerified = false
            accountExists = false
            return
        }
        
        // 创建新的延时任务 - 不使用 weak self，因为 struct 是值类型
        let workItem = DispatchWorkItem {
            self.verifyAccount()
        }
        verifyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
    
    /// 校验账号是否已存在
    private func verifyAccount() {
        guard !userAccount.isEmpty else { return }
        
        isVerifyingAccount = true
        accountVerified = false
        
        HTTPClient.shared.vertifyUser(userAccount: userAccount) { result in
            DispatchQueue.main.async {
                self.isVerifyingAccount = false
                self.accountVerified = true
                
                switch result {
                case .success(let data):
                    self.accountExists = (data == 1)
                    if self.accountExists {
                        self.alertMessage = "该账号已被注册"
                        self.showAlert = true
                    }
                case .failure(let error):
                    print("❌ 校验账号失败: \(error.localizedDescription)")
                    self.accountExists = false
                }
            }
        }
    }
    
    /// 验证密码是否一致
    private func validatePasswordMatch() {
        isPasswordMatch = password == confirmPassword
    }
    
    /// 验证手机号格式
    private func validatePhone() {
        if telephone.isEmpty {
            isPhoneValid = true
            return
        }
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        isPhoneValid = phonePredicate.evaluate(with: telephone)
    }
    
    /// 验证邮箱格式
    private func validateEmail() {
        if email.isEmpty {
            isEmailValid = false
            return
        }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    /// 格式化日期为字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - 注册处理
    
    /// 处理注册
    private func handleRegister() {
        // 额外校验
        if !isPasswordMatch {
            alertMessage = "两次输入的密码不一致"
            showAlert = true
            return
        }
        
        if !isPhoneValid && !telephone.isEmpty {
            alertMessage = "请输入正确的手机号码"
            showAlert = true
            return
        }
        
        if !isEmailValid {
            alertMessage = "请输入正确的邮箱地址"
            showAlert = true
            return
        }
        
        if accountExists {
            alertMessage = "该账号已被注册"
            showAlert = true
            return
        }
        
        isRegistering = true
        
        // 构建用户数据
        var userData = UserData(
            id: nil,
            userAccount: userAccount,
            createDate: nil,
            updateDate: nil,
            username: username,
            telephone: telephone,
            email: email,
            avater: nil,
            birthday: formatDate(birthday),
            sex: selectedGender,
            role: nil,
            password: password,
            sign: sign,
            region: region,
            disabled: nil,
            permission: nil
        )
        
        HTTPClient.shared.register(userData: userData) { result in
            DispatchQueue.main.async {
                self.isRegistering = false
                
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
    RegisterPage()
}
