//
//  CompanyPage.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

/// 公司/空间选择页面
struct CompanyPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var companies: [Company] = []
    @State private var selectedCompanyId: String?
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var navigateToChat = false
    
    // 是否为手动添加的公司选择（登录后无公司数据时）
    @State private var isManualSelection = false
    
    // 是否来自用户页面（切换公司）
    @State private var isFromUserPage = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 自定义导航栏
                customNavigationBar
                
                // 内容区域
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: Dimens.middleMargin) {
                            // 公司列表卡片
                            if companies.isEmpty && !isManualSelection {
                                emptyStateView
                            } else {
                                ForEach(companies) { company in
                                    CompanyCard(
                                        company: company,
                                        isSelected: selectedCompanyId == company.id,
                                        onSelect: {
                                            selectedCompanyId = company.id
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.top, Dimens.middleMargin)
                    }
                }
                
                Spacer()
                
                // 底部确定按钮
                bottomButtonView
            }
            .background(Colors.pageBackgroundColor)
            .navigationBarHidden(true)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $navigateToChat) {
                HomePage()
                    .navigationBarHidden(true)
            }
        }
        .onAppear {
            loadCompanies()
        }
    }
    
    // MARK: - 视图组件
    
    /// 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 返回按钮（仅当从UserPage进入时显示）
            if isFromUserPage {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Dimens.middleIcon))
                        .foregroundColor(Colors.primaryColor)
                }
            } else {
                Color.clear
                    .frame(width: Dimens.middleIcon)
            }
            
            Spacer()
            
            // 标题
            Text(isManualSelection ? "选择空间" : "选择公司")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            Color.clear
                .frame(width: Dimens.middleIcon)
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
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "building.2")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            
            Text("暂无公司信息")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
            
            Text("请先联系管理员添加公司")
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)
        }
        .padding(.vertical, Dimens.largeMargin * 2)
    }
    
    /// 底部按钮视图
    private var bottomButtonView: some View {
        VStack {
            Button(action: handleConfirm) {
                Text("确定")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.whiteColor)
                    .frame(height: Dimens.btnHeight)
                    .frame(maxWidth: .infinity)
                    .background(selectedCompanyId != nil ? Colors.primaryColor : Colors.grayColor)
                    .cornerRadius(Dimens.btnHeight / 2)
            }
            .disabled(selectedCompanyId == nil)
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
        }
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - 数据加载方法
    
    /// 加载公司列表
    private func loadCompanies() {
        isLoading = true
        
        // 获取当前登录用户的 userId
        let userId = AppState.shared.userData?.id
        
        // 从缓存获取 companyId（拼接 userId）
        var cachedCompanyId: String? = nil
        if let userId = userId {
            let key = "companyId_\(userId)"
            cachedCompanyId = UserDefaults.standard.string(forKey: key)
            print("📦 从缓存获取 companyId: key=\(key), value=\(cachedCompanyId ?? "nil")")
        }
        
        // 判断是否从 UserPage 进入
        // 通过检查 navigation path 来判断，这里简单用标志位
        // 实际可以通过 Environment 或传递参数
        isFromUserPage = checkIfFromUserPage()
        
        // 调用获取公司列表接口
        HTTPClient.shared.getCompanyList { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let companyList):
                    self.companies = companyList
                    
                    // 如果有缓存的 companyId，尝试匹配
                    if let cachedId = cachedCompanyId,
                       let matchedCompany = companyList.first(where: { $0.id == cachedId }) {
                        // 找到匹配的公司，自动选中并跳转
                        self.selectedCompanyId = matchedCompany.id
                        self.saveSelectedCompany(matchedCompany)
                        self.navigateToChat = true
                    } else if companyList.isEmpty {
                        // 公司列表为空，进入手动选择模式（添加示例数据）
                        self.isManualSelection = true
                        self.loadManualCompanies()
                    } else if companyList.count == 1 && cachedCompanyId == nil {
                        // 只有一个公司且没有缓存，自动选中
                        self.selectedCompanyId = companyList.first?.id
                    } else if let userId = userId, cachedCompanyId == nil {
                        // 有用户ID但没有缓存的公司ID，需要用户手动选择
                        print("⚠️ 未找到缓存的 companyId，需要用户手动选择公司")
                    }
                    
                case .failure(let error):
                    print("❌ 获取公司列表失败: \(error.localizedDescription)")
                    // 获取失败时，进入手动选择模式（添加示例数据）
                    self.isManualSelection = true
                    self.loadManualCompanies()
                }
            }
        }
    }
    
    /// 加载手动添加的公司数据（登录后无公司数据时使用）
    private func loadManualCompanies() {
        // 手动添加一条示例公司数据作为"个人空间"
        let manualCompany = Company(
            id: "manual_company_001",
            name: "我的工作空间",
            code: "WORKSPACE_001",
            description: "个人工作空间",
            status: 1,
            createDate: nil,
            updateDate: nil,
            createdBy: "",
            updatedBy: ""
        )
        companies = [manualCompany]
    }
    
    /// 保存选中的公司
    private func saveSelectedCompany(_ company: Company) {
        // 保存到全局状态
        AppState.shared.saveCurrentCompany(company)
        
        // 将 companyId 拼接 userId 保存到缓存
        let userId = AppState.shared.userData?.id
        if let userId = userId {
            let key = "companyId_\(userId)"
            UserDefaults.standard.set(company.id, forKey: key)
            print("💾 保存公司ID到缓存: key=\(key), value=\(company.id)")
        }
    }
    
    /// 处理确定按钮点击
    private func handleConfirm() {
        guard let companyId = selectedCompanyId,
              let selectedCompany = companies.first(where: { $0.id == companyId }) else {
            return
        }
        
        saveSelectedCompany(selectedCompany)
        
        // 跳转到 HomePage，且不能返回
        navigateToChat = true
    }
    
    /// 判断是否从 UserPage 进入
    private func checkIfFromUserPage() -> Bool {
        // 通过导航栈判断
        // 这里简单返回 false，实际使用时可以通过环境变量或初始化参数传入
        return false
    }
}

// MARK: - 公司卡片组件

/// 公司卡片视图
struct CompanyCard: View {
    let company: Company
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // 公司信息
                VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                    Text(company.name)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                    
                    if let description = company.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: Dimens.normalFont - 2))
                            .foregroundColor(Colors.grayColor)
                            .lineLimit(1)
                    }
                    
                    // 公司编码
                    Text("编码: \(company.code)")
                        .font(.system(size: Dimens.normalFont - 3))
                        .foregroundColor(Colors.grayColor)
                }
                
                Spacer()
                
                // 单选按钮
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Colors.primaryColor : Colors.grayColor)
                    .font(.system(size: Dimens.middleIcon))
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CompanyPage()
}