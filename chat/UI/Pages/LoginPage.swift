import SwiftUI

struct LoginPage: View {
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab = 0 // 0: 账号密码登录, 1: 邮箱验证码登录
    
    // 账号密码登录相关
    @State private var account = "吴时吴刻"
    @State private var password = ""
    @State private var isLoggingIn = false
    
    // 邮箱验证码登录相关
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var isSendingCode = false
    @State private var isEmailValid = false
    @State private var countdown = 0
    @State private var timer: Timer?
    
    // 通用
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var isLoginButtonEnabled: Bool {
        if selectedTab == 0 {
            return !account.isEmpty && !password.isEmpty
        } else {
            return isEmailValid && !verificationCode.isEmpty
        }
    }
    
    var body: some View {
        ZStack {
            Colors.pageBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 顶部logo
                AIAvatar.large()
                
                Spacer()
                    .frame(height: Dimens.middleMargin)
                
                // 登录面板
                VStack(spacing: Dimens.middleMargin) {
                    // Tab切换
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation {
                                selectedTab = 0
                            }
                        }) {
                            VStack(spacing: Dimens.middleMargin / 2) {
                                Text("账号密码登录")
                                    .font(.system(size: Dimens.normalFont))
                                    .foregroundColor(selectedTab == 0 ? Colors.primaryColor : Colors.grayColor)
                                Rectangle()
                                    .fill(selectedTab == 0 ? Colors.primaryColor : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: {
                            withAnimation {
                                selectedTab = 1
                            }
                        }) {
                            VStack(spacing: Dimens.middleMargin / 2) {
                                Text("邮箱验证码登录")
                                    .font(.system(size: Dimens.normalFont))
                                    .foregroundColor(selectedTab == 1 ? Colors.primaryColor : Colors.blackColor)
                                Rectangle()
                                    .fill(selectedTab == 1 ? Colors.primaryColor : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if selectedTab == 0 {
                        // 账号密码登录面板
                        VStack(spacing: Dimens.middleMargin) {
                            CustomTextField(
                                text: $account,
                                placeholder: "请输入账号",
                                isSecure: false
                            )
                            
                            CustomTextField(
                                text: $password,
                                placeholder: "请输入密码",
                                isSecure: true
                            )
                        }
                    } else {
                        // 邮箱验证码登录面板
                        VStack(spacing: Dimens.middleMargin) {
                            // 邮箱输入框（带内部发送按钮）
                            ZStack(alignment: .trailing) {
                                TextField("请输入邮箱", text: $email)
                                    .font(.system(size: Dimens.normalFont))
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .onChange(of: email) { newValue in
                                        validateEmail()
                                    }
                                    .padding(.horizontal, Dimens.middleMargin)
                                    .padding(.trailing, Dimens.inputHeight + Dimens.middleMargin)
                                    .frame(height: Dimens.inputHeight)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                                            .stroke(Colors.grayColor, lineWidth: 1)
                                    )
                                
                                Button(action: sendVerificationCode) {
                                    Image(systemName: "paperplane.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: Dimens.smallIcon, height: Dimens.smallIcon)
                                        .foregroundColor(isEmailValid && countdown == 0 ? Colors.primaryColor : Colors.grayColor)
                                        .frame(width: Dimens.inputHeight, height: Dimens.inputHeight)
                                }
                                .disabled(!isEmailValid || isSendingCode || countdown > 0)
                                .padding(.trailing, Dimens.middleMargin)
                            }
                            
                            // 验证码输入框
                            ZStack(alignment: .trailing) {
                                TextField("请输入验证码", text: $verificationCode)
                                    .font(.system(size: Dimens.normalFont))
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, Dimens.middleMargin)
                                    .padding(.trailing, countdown > 0 ? Dimens.inputHeight + Dimens.middleMargin : Dimens.middleMargin)
                                    .frame(height: Dimens.inputHeight)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                                            .stroke(Colors.grayColor, lineWidth: 1)
                                    )
                                
                                if countdown > 0 {
                                    Text("\(countdown)s")
                                        .font(.system(size: Dimens.normalFont))
                                        .foregroundColor(Colors.grayColor)
                                        .frame(width: Dimens.inputHeight, height: Dimens.inputHeight)
                                        .padding(.trailing, Dimens.middleMargin)
                                }
                            }
                        }
                    }
                    
                    // 登录按钮
                    Button(action: handleLogin) {
                        HStack(spacing: Dimens.smallIcon) {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                                    .frame(width: Dimens.smallIcon, height: Dimens.smallIcon)
                            }
                            Text(isLoggingIn ? "" : "登录")
                                .font(.system(size: Dimens.normalFont))
                        }
                        .foregroundColor(.themeWhite)
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(isLoginButtonEnabled ? Colors.primaryColor : Colors.grayColor)
                        .cornerRadius(Dimens.btnHeight)
                    }
                    .disabled(!isLoginButtonEnabled || isLoggingIn)
                    
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
                Spacer()
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - 邮箱验证
    private func validateEmail() {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    // MARK: - 发送验证码
    private func sendVerificationCode() {
        guard isEmailValid else { return }
        
        isSendingCode = true
        
        HTTPClient.shared.sendEmailVerificationCode(email: email) { result in
            DispatchQueue.main.async {
                isSendingCode = false
                
                switch result {
                case .success(let response):
                    alertMessage = response.msg ?? "验证码已发送"
                    showAlert = true
                    
                    // 开始倒计时
                    if response.isSuccess {
                        startCountdown()
                    }
                    
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    // MARK: - 开始倒计时
    private func startCountdown() {
        countdown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if countdown > 0 {
                    countdown -= 1
                } else {
                    timer?.invalidate()
                    timer = nil
                }
            }
        }
    }
    
    // MARK: - 登录处理
    private func handleLogin() {
        if selectedTab == 0 {
            handlePasswordLogin()
        } else {
            handleEmailLogin()
        }
    }
    
    // MARK: - 密码登录
    private func handlePasswordLogin() {
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
    
    // MARK: - 邮箱登录
    private func handleEmailLogin() {
        isLoggingIn = true
        
        HTTPClient.shared.loginByEmail(email: email, code: verificationCode) { result in
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
    
    // MARK: - 注册处理
    private func handleRegister() {
        print("注册按钮点击 - 待实现")
    }
    
    // MARK: - 忘记密码处理
    private func handleForgotPassword() {
        print("忘记密码按钮点击 - 待实现")
    }
}

#Preview {
    LoginPage()
}
