//
//  UpdateModelPage.swift
//  chat
//
//  Created by 吴文强 on 2026/7/7.
//

import SwiftUI

/// 更新模型页面
struct UpdateModelPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    let model: ChatModel
    let onModelUpdated: (() -> Void)?
    
    @State private var modelName = ""
    @State private var modelType = "ollama"
    @State private var baseUrl = ""
    @State private var apiKey = ""
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shouldDismiss = false
    
    private let modelTypes = ["ollama", "online"]
    
    init(model: ChatModel, onModelUpdated: (() -> Void)? = nil) {
        self.model = model
        self.onModelUpdated = onModelUpdated
    }
    
    var body: some View {
        VStack(spacing: 0) {
            customNavigationBar
            
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    formCardView
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
                    onModelUpdated?()
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadModelData()
        }
    }
    
    // MARK: - 视图组件
    
    private var customNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.subColor)
            }
            
            Spacer()
            
            Text("更新模型")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.black)
            
            Spacer()
            
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
    
    private var formCardView: some View {
        VStack(spacing: 0) {
            formRow(
                label: "模型名称",
                isRequired: true,
                content: AnyView(
                    TextField("请输入模型名称", text: $modelName)
                        .font(.system(size: Dimens.normalFont))
                )
            )
            
            DividerLine()
            
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
                )
            )
            
            DividerLine()
            
            formRow(
                label: "模型地址",
                isRequired: true,
                content: AnyView(
                    TextField("请输入模型地址", text: $baseUrl)
                        .font(.system(size: Dimens.normalFont))
                        .autocapitalization(.none)
                )
            )
            
            DividerLine()
            
            formRow(
                label: "API Key",
                isRequired: false,
                content: AnyView(
                    TextField("请输入API Key（可选）", text: $apiKey)
                        .font(.system(size: Dimens.normalFont))
                        .autocapitalization(.none)
                )
            )
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    private func DividerLine() -> some View {
        Rectangle()
            .fill(Colors.grayColor.opacity(0.3))
            .frame(height: 1)
            .padding(.leading, Dimens.middleMargin)
    }
    
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
    
    private var actionButtonsView: some View {
        HStack(spacing: Dimens.middleMargin) {
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
            
            Button(action: handleUpdateModel) {
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
    
    // MARK: - 数据加载
    
    private func loadModelData() {
        modelName = model.modelName
        modelType = model.type
        baseUrl = model.baseUrl
        apiKey = model.apiKey ?? ""
    }
    
    // MARK: - 表单校验
    
    private var isFormValid: Bool {
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !trimmedUrl.isEmpty
    }
    
    // MARK: - 数据提交
    
    private func handleUpdateModel() {
        guard let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            alertMessage = "未找到公司ID"
            showAlert = true
            return
        }
        
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSubmitting = true
        
        HTTPClient.shared.updateModel(
            modelId: model.id,
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
                        self.alertMessage = "更新成功"
                        self.shouldDismiss = true
                        self.showAlert = true
                    } else {
                        self.alertMessage = "更新失败，请稍后重试"
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
    UpdateModelPage(model: ChatModel(
        id: "1",
        modelName: "DeepSeek-R1",
        type: "online",
        baseUrl: "https://api.deepseek.com/v1",
        apiKey: "sk-xxx",
        companyId: "company1",
        updateTime: "2026-07-01 10:00:00",
        createTime: "2026-07-01 10:00:00"
    ))
}
