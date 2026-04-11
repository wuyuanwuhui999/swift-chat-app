import SwiftUI
import PhotosUI

/// 用户信息页面
struct UserPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var userData: UserData?
    @State private var isLoading = false
    
    // 头像相关状态
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUploadingAvatar = false
    @State private var showAvatarAlert = false
    @State private var avatarAlertMessage = ""
    
    // 编辑对话框状态
    @State private var showEditNicknameDialog = false
    @State private var editNicknameText = ""
    
    @State private var showEditPhoneDialog = false
    @State private var editPhoneText = ""
    
    @State private var showEditEmailDialog = false
    @State private var editEmailText = ""
    
    @State private var showGenderDialog = false
    @State private var selectedGender = 0
    
    @State private var showEditBirthdayDialog = false
    @State private var selectedBirthday = Date()
    
    @State private var showEditRegionDialog = false
    @State private var editRegionText = ""
    
    @State private var showEditSignDialog = false
    @State private var editSignText = ""
    
    // 通用状态
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 跳转状态
    @State private var showChangePasswordPage = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义白色背景标题栏
            customNavigationBar
            
            // 可滚动内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 白色背景圆角矩形卡片
                    VStack(spacing: 0) {
                        // 头像行
                        avatarRow
                        
                        DividerLine()
                        
                        // 昵称行
                        infoRow(
                            label: "昵称",
                            value: userData?.username ?? "",
                            onTap: { showEditNickname() }
                        )
                        
                        DividerLine()
                        
                        // 电话行
                        infoRow(
                            label: "电话",
                            value: userData?.telephone ?? "",
                            onTap: { showEditPhone() }
                        )
                        
                        DividerLine()
                        
                        // 邮箱行
                        infoRow(
                            label: "邮箱",
                            value: userData?.email ?? "",
                            onTap: { showEditEmail() }
                        )
                        
                        DividerLine()
                        
                        // 性别行
                        infoRow(
                            label: "性别",
                            value: getGenderText(userData?.sex ?? 0),
                            onTap: { showGenderDialog = true }
                        )
                        
                        DividerLine()
                        
                        // 出生日期行
                        infoRow(
                            label: "出生日期",
                            value: userData?.birthday ?? "",
                            onTap: { showEditBirthday() }
                        )
                        
                        DividerLine()
                        
                        // 地区行
                        infoRow(
                            label: "地区",
                            value: userData?.region ?? "",
                            onTap: { showEditRegion() }
                        )
                        
                        DividerLine()
                        
                        // 个性签名行
                        infoRow(
                            label: "个性签名",
                            value: userData?.sign ?? "",
                            onTap: { showEditSign() }
                        )
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.borderRadius)
                    
                    // 修改密码按钮
                    Button(action: {
                        showChangePasswordPage = true
                    }) {
                        Text("修改密码")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.primaryColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Colors.whiteColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                    .stroke(Colors.primaryColor, lineWidth: 1)
                            )
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.btnHeight / 2)
                    
                    // 退出登录按钮
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        Text("退出登录")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.warnColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Colors.whiteColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                    .stroke(Colors.warnColor, lineWidth: 1)
                            )
                    }
                    .background(Colors.whiteColor)
                    .cornerRadius(Dimens.btnHeight / 2)
                    .padding(.bottom, Dimens.middleMargin)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
        }
        .background(Colors.pageBackgroundColor)
        .onAppear {
            loadUserData()
        }
        // 头像选择器
        .photosPicker(isPresented: $showAvatarPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _ in
            Task {
                await loadSelectedImage()
            }
        }
        // 各种对话框
        .overlay(editNicknameDialog)
        .overlay(editPhoneDialog)
        .overlay(editEmailDialog)
        .overlay(genderDialog)
        .overlay(editBirthdayDialog)
        .overlay(editRegionDialog)
        .overlay(editSignDialog)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                handleLogout()
            }
        } message: {
            Text("确定要退出登录吗？")
        }
        .fullScreenCover(isPresented: $showChangePasswordPage) {
            ChangePasswordPage()
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
                    .foregroundColor(Colors.primaryColor)
            }
            
            Spacer()
            
            // 标题 - 显示当前租户名称
            if let tenant = appState.currentTenant {
                Text(tenant.name)
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.primary)
            } else {
                Text("个人信息")
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.primary)
            }
            
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
            .padding(.horizontal, Dimens.middleMargin)
    }
    
    /// 头像行视图
    private var avatarRow: some View {
        HStack {
            Text("头像")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 头像显示
            Group {
                if isUploadingAvatar {
                    ProgressView()
                        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                } else if let imageData = selectedImageData,
                          let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                        .clipShape(Circle())
                } else if let avatarUrl = userData?.avater, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: Constants.baseURL + avatarUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                                .clipShape(Circle())
                        case .failure:
                            defaultAvatarView
                        @unknown default:
                            defaultAvatarView
                        }
                    }
                } else {
                    defaultAvatarView
                }
            }
            .onTapGesture {
                showAvatarPicker = true
            }
            
            // 向右箭头
            Image(systemName: "chevron.right")
                .foregroundColor(Colors.grayColor)
                .font(.system(size: Dimens.smallIcon))
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
    
    /// 默认头像视图
    private var defaultAvatarView: some View {
        ZStack {
            Colors.primaryColor.opacity(0.7)
                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                .clipShape(Circle())
            
            Text(getFirstCharacter())
                .font(.system(size: Dimens.bigAvater * 0.4))
                .foregroundColor(.white)
        }
        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
    }
    
    /// 信息行视图
    private func infoRow(label: String, value: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value.isEmpty ? "未设置" : value)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(value.isEmpty ? Colors.grayColor : .primary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Colors.grayColor)
                    .font(.system(size: Dimens.smallIcon))
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
        }
    }
    
    // MARK: - 辅助方法
    
    /// 获取用户名的第一个字符
    private func getFirstCharacter() -> String {
        guard let firstChar = userData?.username.first else {
            return "?"
        }
        return String(firstChar)
    }
    
    /// 获取性别文本
    private func getGenderText(_ sex: Int) -> String {
        switch sex {
        case 0:
            return "男"
        case 1:
            return "女"
        default:
            return "未设置"
        }
    }
    
    /// 加载用户数据
    private func loadUserData() {
        if let userData = appState.userData {
            self.userData = userData
            editNicknameText = userData.username
            editPhoneText = userData.telephone
            editEmailText = userData.email
            selectedGender = userData.sex
            editRegionText = userData.region ?? ""
            editSignText = userData.sign
            // birthday 是可选类型，使用可选绑定解包
            if let birthday = userData.birthday, !birthday.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: birthday) {
                    selectedBirthday = date
                }
            }
        }
    }
    
    /// 显示编辑昵称对话框
    private func showEditNickname() {
        editNicknameText = userData?.username ?? ""
        showEditNicknameDialog = true
    }
    
    /// 显示编辑电话对话框
    private func showEditPhone() {
        editPhoneText = userData?.telephone ?? ""
        showEditPhoneDialog = true
    }
    
    /// 显示编辑邮箱对话框
    private func showEditEmail() {
        editEmailText = userData?.email ?? ""
        showEditEmailDialog = true
    }
    
    /// 显示编辑出生日期对话框
    private func showEditBirthday() {
        showEditBirthdayDialog = true
    }
    
    /// 显示编辑地区对话框
    private func showEditRegion() {
        editRegionText = userData?.region ?? ""
        showEditRegionDialog = true
    }
    
    /// 显示编辑个性签名对话框
    private func showEditSign() {
        editSignText = userData?.sign ?? ""
        showEditSignDialog = true
    }
    
    /// 保存用户信息到服务器
    private func saveUserInfo(completion: @escaping (Bool) -> Void) {
        guard var updatedUser = userData else {
            completion(false)
            return
        }
        
        // 更新用户数据
        updatedUser.username = editNicknameText
        updatedUser.telephone = editPhoneText
        updatedUser.email = editEmailText
        updatedUser.sex = selectedGender
        updatedUser.birthday = formatDate(selectedBirthday)
        updatedUser.region = editRegionText
        updatedUser.sign = editSignText
        
        HTTPClient.shared.updateUser(userData: updatedUser) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newUserData):
                    self.userData = newUserData
                    appState.updateUserData(newUserData)
                    completion(true)
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                    completion(false)
                }
            }
        }
    }
    
    /// 格式化日期为字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// 验证手机号格式
    private func validatePhone(_ phone: String) -> Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    /// 验证邮箱格式
    private func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// 处理退出登录
    private func handleLogout() {
        // 清除用户数据
        appState.clearUserData()
        // 关闭当前页面
        dismiss()
    }
    
    // MARK: - 头像选择相关
    
    @State private var showAvatarPicker = false
    
    /// 加载选中的图片
    private func loadSelectedImage() async {
        guard let item = selectedItem else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedImageData = data
                    uploadAvatar(imageData: data)
                }
            }
        } catch {
            print("❌ 加载图片失败: \(error)")
        }
    }
    
    /// 上传头像
    private func uploadAvatar(imageData: Data) {
        isUploadingAvatar = true
        
        HTTPClient.shared.updateAvatar(imageData: imageData) { result in
            DispatchQueue.main.async {
                isUploadingAvatar = false
                
                switch result {
                case .success(let avatarUrl):
                    // 更新本地用户数据
                    var updatedUser = userData
                    updatedUser?.avater = avatarUrl
                    userData = updatedUser
                    if let updatedUser = updatedUser {
                        appState.updateUserData(updatedUser)
                    }
                    alertMessage = "头像更新成功"
                    showAlert = true
                    
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                    // 清除选中的图片数据
                    selectedImageData = nil
                }
            }
        }
    }
}

// MARK: - 对话框扩展

extension UserPage {
    /// 编辑昵称对话框
    @ViewBuilder
    private var editNicknameDialog: some View {
        if showEditNicknameDialog {
            CustomDialog(
                isPresented: $showEditNicknameDialog,
                title: "修改昵称",
                content: {
                    TextField("请输入昵称", text: $editNicknameText)
                        .font(.system(size: Dimens.normalFont))
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Colors.pageBackgroundColor)
                        .cornerRadius(Dimens.inputHeight / 2)
                },
                onConfirm: {
                    if editNicknameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        alertMessage = "昵称不能为空"
                        showAlert = true
                        return
                    }
                    saveUserInfo { success in
                        if success {
                            showEditNicknameDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 编辑电话对话框
    @ViewBuilder
    private var editPhoneDialog: some View {
        if showEditPhoneDialog {
            CustomDialog(
                isPresented: $showEditPhoneDialog,
                title: "修改电话",
                content: {
                    TextField("请输入电话号码", text: $editPhoneText)
                        .font(.system(size: Dimens.normalFont))
                        .keyboardType(.phonePad)
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Colors.pageBackgroundColor)
                        .cornerRadius(Dimens.inputHeight / 2)
                },
                onConfirm: {
                    if !editPhoneText.isEmpty && !validatePhone(editPhoneText) {
                        alertMessage = "请输入正确的手机号码"
                        showAlert = true
                        return
                    }
                    saveUserInfo { success in
                        if success {
                            showEditPhoneDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 编辑邮箱对话框
    @ViewBuilder
    private var editEmailDialog: some View {
        if showEditEmailDialog {
            CustomDialog(
                isPresented: $showEditEmailDialog,
                title: "修改邮箱",
                content: {
                    TextField("请输入邮箱", text: $editEmailText)
                        .font(.system(size: Dimens.normalFont))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Colors.pageBackgroundColor)
                        .cornerRadius(Dimens.inputHeight / 2)
                },
                onConfirm: {
                    if !editEmailText.isEmpty && !validateEmail(editEmailText) {
                        alertMessage = "请输入正确的邮箱地址"
                        showAlert = true
                        return
                    }
                    saveUserInfo { success in
                        if success {
                            showEditEmailDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 性别选择对话框
    @ViewBuilder
    private var genderDialog: some View {
        if showGenderDialog {
            CustomSelectionDialog(
                isPresented: $showGenderDialog,
                title: "选择性别",
                options: ["男", "女"],
                selectedIndex: selectedGender,
                onConfirm: { index in
                    selectedGender = index
                    saveUserInfo { success in
                        if success {
                            showGenderDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 编辑出生日期对话框
    @ViewBuilder
    private var editBirthdayDialog: some View {
        if showEditBirthdayDialog {
            CustomDatePickerDialog(
                isPresented: $showEditBirthdayDialog,
                title: "选择出生日期",
                selectedDate: selectedBirthday,
                onConfirm: { date in
                    selectedBirthday = date
                    saveUserInfo { success in
                        if success {
                            showEditBirthdayDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 编辑地区对话框
    @ViewBuilder
    private var editRegionDialog: some View {
        if showEditRegionDialog {
            CustomDialog(
                isPresented: $showEditRegionDialog,
                title: "修改地区",
                content: {
                    TextField("请输入地区", text: $editRegionText)
                        .font(.system(size: Dimens.normalFont))
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Colors.pageBackgroundColor)
                        .cornerRadius(Dimens.inputHeight / 2)
                },
                onConfirm: {
                    saveUserInfo { success in
                        if success {
                            showEditRegionDialog = false
                        }
                    }
                }
            )
        }
    }
    
    /// 编辑个性签名对话框
    @ViewBuilder
    private var editSignDialog: some View {
        if showEditSignDialog {
            CustomDialog(
                isPresented: $showEditSignDialog,
                title: "修改个性签名",
                content: {
                    TextEditor(text: $editSignText)
                        .font(.system(size: Dimens.normalFont))
                        .frame(height: 100)
                        .padding(.horizontal, Dimens.middleMargin)
                        .background(Colors.pageBackgroundColor)
                        .cornerRadius(Dimens.borderRadius)
                },
                onConfirm: {
                    saveUserInfo { success in
                        if success {
                            showEditSignDialog = false
                        }
                    }
                }
            )
        }
    }
}

#Preview {
    UserPage()
}
