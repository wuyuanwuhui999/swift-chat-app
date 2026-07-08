//
//  AddModelPage.swift
//  chat
//
//  Created by 吴文强 on 2026/7/7.
//

import SwiftUI

/// 添加模型页面
struct AddModelPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    let onModelAdded: (() -> Void)?
    
    @State private var modelName = ""
    @State private var modelType = "ollama"
    @State private var baseUrl = ""
    @State private var apiKey = ""
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shouldDismiss = false
    
    // 模型类型选项
    private let modelTypes = ["ollama", "online"]
    
    init(onModelAdded: (() -> Void)? = nil) {
        self.onModelAdded = onModelAdded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            customNavigationBar
            
            // 内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 表单卡片
                    formCardView
                    
                    // 确定/取消按钮
                    actionButtonsView
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
                .padding(.bottom, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
        }
        .background(Colors.pageBackgroundColor)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {
                if shouldDismiss {
                    onModelAdded?()
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .navigationBarHidden(true)
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
            Text("添加模型")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
            // 占位按钮
            Color.clear
                .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
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
    
    /// 表单卡片视图
    private var formCardView: some View {
        VStack(spacing: 0) {
            // 模型名称
            formRow(
                label: "模型名称",
                isRequired: true,
                content: AnyView(
                    TextField("", text: $modelName, prompt: Text("请输入模型名称").foregroundColor(Colors.grayColor))
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                        .frame(minWidth: 0, maxWidth: .infinity)
                )
            )
            
            DividerLine()
            
            // 模型类型
            formRow(
                label: "模型类型",
                isRequired: true,
                content: AnyView(
                    Picker("", selection: $modelType) {
                        ForEach(modelTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tint(.black)
                )
            )
            
            DividerLine()
            
            // 模型地址
            formRow(
                label: "模型地址",
                isRequired: true,
                content: AnyView(
                    TextField("", text: $baseUrl, prompt: Text("请输入模型地址").foregroundColor(Colors.grayColor))
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .frame(minWidth: 0, maxWidth: .infinity)
                )
            )
            
            DividerLine()
            
            // API Key
            formRow(
                label: "API Key",
                isRequired: false,
                content: AnyView(
                    TextField("", text: $apiKey, prompt: Text("请输入API Key（可选）").foregroundColor(Colors.grayColor))
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .frame(minWidth: 0, maxWidth: .infinity)
                )
            )
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
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
            HStack(spacing: 2) {
                if isRequired {
                    Text("*")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.warnColor)
                }
                Text(label)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
            }
            .frame(width: 80, alignment: .leading)
            
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
    
    /// 确定/取消按钮视图
    private var actionButtonsView: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 取消按钮
            Button(action: {
                dismiss()
            }) {
                Text("取消")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.grayColor)
                    .frame(height: Dimens.btnHeight)
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                            .stroke(Colors.grayColor, lineWidth: 1)
                    )
            }
            
            // 确定按钮
            Button(action: handleAddModel) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("确定")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                }
            }
            .frame(height: Dimens.btnHeight)
            .frame(maxWidth: .infinity)
            .background(isFormValid ? Colors.primaryColor : Colors.grayColor)
            .cornerRadius(Dimens.btnHeight / 2)
            .disabled(!isFormValid || isSubmitting)
        }
    }
    
    // MARK: - 表单校验
    
    /// 表单是否有效
    private var isFormValid: Bool {
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedUrl.isEmpty
    }
    
    // MARK: - 数据提交方法
    
    /// 添加模型
    private func handleAddModel() {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            alertMessage = "未找到公司ID"
            showAlert = true
            return
        }
        
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSubmitting = true
        
        HTTPClient.shared.addModel(
            modelName: trimmedName,
            type: modelType,
            companyId: companyId,
            apiKey: trimmedApiKey.isEmpty ? nil : trimmedApiKey,
            baseUrl: trimmedUrl
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                switch result {
                case .success(let data):
                    if data > 0 {
                        self.alertMessage = "添加成功"
                        self.shouldDismiss = true
                        self.showAlert = true
                    } else {
                        self.alertMessage = "添加失败，请稍后重试"
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
    AddModelPage()
}