//
//  AddPromptPage.swift
//  chat
//
//  Created by 吴文强 on 2026/7/3.
//

import SwiftUI

/// 添加提示词页面
struct AddPromptPage: View {
    @ObservedObject private var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss
    
    // ✅ 添加回调闭包：添加成功后通知父页面刷新
    let onPromptAdded: (() -> Void)?
    
    @State private var promptText = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shouldDismiss = false
    
    // ✅ 新增：支持无回调初始化
    init(onPromptAdded: (() -> Void)? = nil) {
        self.onPromptAdded = onPromptAdded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            customNavigationBar
            
            // 内容区域
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 提示词编辑卡片
                    promptCardView
                    
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
                    // ✅ 添加成功后，先执行回调再关闭页面
                    onPromptAdded?()
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
            Text("添加提示词")
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
    
    /// 提示词编辑卡片视图
    private var promptCardView: some View {
        VStack(alignment: .leading, spacing: Dimens.middleMargin) {
            // 卡片标题
            Text("提示词内容")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.black)
            
            // 提示词编辑框
            ZStack(alignment: .topLeading) {
                TextEditor(text: $promptText)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
                    .frame(minHeight: 200)
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.middleMargin)
                    .cornerRadius(Dimens.borderRadius)
                    .scrollContentBackground(.hidden)
                    .background(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimens.borderRadius)
                            .stroke(Colors.grayColor, lineWidth: 1)
                    )
                
                // 占位文字
                if promptText.isEmpty {
                    Text("请输入提示词内容...")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.grayColor)
                        .padding(.horizontal, Dimens.middleMargin + 5)
                        .padding(.vertical, Dimens.middleMargin + 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(Dimens.middleMargin)
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
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
            Button(action: handleAddPrompt) {
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
            .background(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Colors.grayColor : Colors.primaryColor)
            .cornerRadius(Dimens.btnHeight / 2)
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        }
    }
    
    // MARK: - 数据提交方法
    
    /// 添加提示词
    private func handleAddPrompt() {
        let trimmedText = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            alertMessage = "提示词不能为空"
            showAlert = true
            return
        }
        
        guard let tenantId = appState.currentTenant?.id else {
            alertMessage = "未找到租户ID"
            showAlert = true
            return
        }
        
        isSubmitting = true
        
        HTTPClient.shared.insertPrompt(
            prompt: trimmedText,
            tenantId: tenantId
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                switch result {
                case .success(let success):
                    if success {
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
    AddPromptPage()
}