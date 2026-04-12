//
//  PromptDialog.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

/// 提示词设置对话框组件
struct PromptDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var promptText = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let onPromptUpdated: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 半透明遮罩层
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                // 对话框内容 - 从底部弹出
                VStack(spacing: 0) {
                    // 标题栏
                    headerView
                    
                    // 内容区域
                    VStack(spacing: Dimens.middleMargin) {
                        // 白色背景圆角矩形
                        VStack(spacing: 0) {
                            // 提示词输入框 - 带占位文字
                            ZStack(alignment: .topLeading) {
                                // 编辑框
                                TextEditor(text: $promptText)
                                    .font(.system(size: Dimens.normalFont))
                                    .frame(minHeight: 200, maxHeight: .infinity)
                                    .padding(.horizontal, Dimens.middleMargin)
                                    .padding(.vertical, Dimens.middleMargin)
                                    .cornerRadius(Dimens.borderRadius)
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
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.top, Dimens.middleMargin)
                        .padding(.bottom, Dimens.middleMargin)
                        .background(Colors.whiteColor)
                        .cornerRadius(Dimens.borderRadius)
                        .padding(.horizontal, Dimens.middleMargin)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // 底部按钮区域
                    bottomActionView
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height * 0.8
                )
                .background(Colors.whiteColor)
                .clipShape(RoundedCorner(radius: Dimens.borderRadius, corners: [.topLeft, .topRight]))
                .position(x: geometry.size.width / 2, y: geometry.size.height - (geometry.size.height * 0.8 / 2))
            }
        }
        .onAppear {
            loadCurrentPrompt()
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        Text("设置提示词")
            .font(.system(size: Dimens.middleFont))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Dimens.middleMargin)
            .background(Colors.whiteColor)
            .overlay(
                Rectangle()
                    .fill(Colors.grayColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    /// 底部操作区域视图
    @ViewBuilder
    private var bottomActionView: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 取消按钮
            Button(action: {
                isPresented = false
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
            Button(action: handleSavePrompt) {
                if isSaving {
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
            .background(promptText.isEmpty ? Colors.grayColor : Colors.primaryColor)
            .cornerRadius(Dimens.btnHeight / 2)
            .disabled(promptText.isEmpty || isSaving)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - 数据加载方法
    
    /// 加载当前提示词
    private func loadCurrentPrompt() {
        // 使用 prompt 字段，而不是 id
        promptText = appState.currentPrompt?.prompt ?? ""
    }
    
    /// 保存提示词
    private func handleSavePrompt() {
        guard !promptText.isEmpty else { return }
        
        isSaving = true
        
        // 构建提示词对象，使用 prompt 字段存储内容
        let prompt = Prompt(
            id: appState.currentPrompt?.id ?? "",  // 如果有 id 则使用，否则为空字符串
            tenantId: appState.currentTenant?.id ?? "",
            userId: appState.userData?.id ?? "",
            prompt: promptText,  // 将输入的文本保存到 prompt 字段
            createTime: appState.currentPrompt?.createTime,
            updateTime: nil
        )
        
        HTTPClient.shared.updatePrompt(prompt: prompt) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success(let updatedPrompt):
                    // 更新本地提示词
                    self.appState.updatePrompt(updatedPrompt)
                    self.alertMessage = "提示词设置成功"
                    self.showAlert = true
                    // 延迟关闭对话框
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isPresented = false
                        self.onPromptUpdated()
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
    PromptDialog(
        isPresented: .constant(true),
        onPromptUpdated: {}
    )
}
