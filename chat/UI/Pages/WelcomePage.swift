import SwiftUI

struct WelcomePage: View {
    @ObservedObject private var appState = AppState.shared
    @State private var isCheckingLogin = true
    @State private var showLoginPage = false
    
    var body: some View {
        ZStack {
            Colors.pageBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 中间显示logo
                if let logoImage = UIImage(named: "logo") {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                } else {
                    // 占位符，如果没有logo图片
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                        .foregroundColor(.themePrimary)
                }
                
                Spacer()
            }
        }
        .onAppear {
            checkLoginStatus()
        }
        .fullScreenCover(isPresented: $appState.isLoggedIn) {
            HomePage()
        }
        .fullScreenCover(isPresented: $showLoginPage) {
            LoginPage()
        }
    }
    
    private func checkLoginStatus() {
        // 检查token是否存在
        if let token = TokenManager.shared.getToken() {
            // 有token，调用getUserData接口
            HTTPClient.shared.getUserData { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let userData):
                        // 保存用户信息到全局
                        AppState.shared.updateUserData(userData)
                        AppState.shared.isLoggedIn = true
                    case .failure(let error):
                        print("获取用户信息失败: \(error.localizedDescription)")
                        AppState.shared.clearUserData()
                        AppState.shared.isLoggedIn = false
                        // 延时1秒后显示登录页
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showLoginPage = true
                        }
                    }
                    isCheckingLogin = false
                }
            }
        } else {
            // 没有token，延时1秒后跳转到登录页
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
