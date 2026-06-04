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
                } else if companies.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: Dimens.middleMargin) {
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
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.top, Dimens.middleMargin)
                    }
                }
                
                Spacer(minLength: 0)
                
                // 底部确定按钮
                bottomButtonView
            }
            .background(Colors.pageBackgroundColor)
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .navigationDestination(isPresented: $navigateToChat) {
                HomePage()
                    .navigationBarHidden(true)
            }
            .onAppear {
                loadCompanies()
            }
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
            Text("选择公司/个人空间")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            Color.clear
                .frame(width: Dimens.middleIcon)
        }
        .frame(height: 50)
        .padding(.horizontal, Dimens.middleMargin)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Dimens.largeMargin * 2)
    }
    
    /// 底部按钮视图
    private var bottomButtonView: some View {
        VStack(spacing: 0) {
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
        if appState.currentCompany != nil {
            isFromUserPage = true
            print("🔍 检测到从 UserPage 进入，当前公司ID: \(appState.currentCompany?.id ?? "nil")")
        }
        
        // 调用获取公司列表接口
        HTTPClient.shared.getCompanyList { result in
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let companyList):
                    self.companies = companyList
                    print("✅ 获取到公司列表，共 \(companyList.count) 家公司")
                    
                    // 打印公司列表详情
                    for company in companyList {
                        print("   - 公司: \(company.name) (ID: \(company.id))")
                    }
                    
                    // 确定选中的公司ID
                    var targetCompanyId: String? = nil
                    
                    // 1. 如果是从 UserPage 进入且有缓存的 currentCompany，优先使用 currentCompany.id
                    if self.isFromUserPage, let currentCompanyId = appState.currentCompany?.id {
                        targetCompanyId = currentCompanyId
                        print("🎯 从 UserPage 进入，使用当前公司ID: \(currentCompanyId)")
                    }
                    // 2. 否则使用缓存的 companyId
                    else if let cachedId = cachedCompanyId {
                        targetCompanyId = cachedId
                        print("🎯 使用缓存的 companyId: \(cachedId)")
                    }
                    
                    // 如果有目标公司ID，尝试匹配
                    if let targetId = targetCompanyId,
                       let matchedCompany = companyList.first(where: { $0.id == targetId }) {
                        // 找到匹配的公司，自动选中
                        self.selectedCompanyId = matchedCompany.id
                        print("✅ 自动选中公司: \(matchedCompany.name) (ID: \(matchedCompany.id))")
                    }
                    // 如果没有匹配的目标公司，且有缓存的 companyId 但未匹配到
                    else if targetCompanyId != nil {
                        print("⚠️ 未找到匹配的公司，需要用户手动选择")
                    }
                    // 公司列表只有一个且没有选中的公司，自动选中
                    else if companyList.count == 1 && self.selectedCompanyId == nil {
                        self.selectedCompanyId = companyList.first?.id
                        print("✅ 只有一家公司，自动选中: \(companyList.first?.name ?? "")")
                    }
                    
                    // 检查是否需要手动选择
                    if self.selectedCompanyId == nil {
                        print("⚠️ 未找到选中的 companyId，需要用户手动选择公司")
                    }
                    
                case .failure(let error):
                    print("❌ 获取公司列表失败: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
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
        
        // 判断是否需要跳转到首页
        if isFromUserPage {
            // 从 UserPage 进入的切换公司，关闭当前页面返回
            print("🔄 切换公司完成，返回 UserPage")
            dismiss()
        } else {
            // 首次登录选择公司，跳转到 HomePage
            print("🚀 首次选择公司，跳转到 HomePage")
            // 修复：直接使用 fullScreenCover 方式跳转，而不是 navigationDestination
            navigateToChat = true
        }
    }
}

// MARK: - 公司卡片组件

/// 公司卡片视图（简化版：只显示公司名称和单选按钮）
struct CompanyCard: View {
    let company: Company
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // 公司名称
                Text(company.name)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
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