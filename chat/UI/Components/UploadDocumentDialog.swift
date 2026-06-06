//
//  UploadDocumentDialog.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI
import UniformTypeIdentifiers

/// 上传文档对话框组件
struct UploadDocumentDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var directories: [Directory] = []
    @State private var isLoading = false
    @State private var selectedDirectoryId: String? = nil
    @State private var isUploading = false
    @State private var showFilePicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let onUploadComplete: () -> Void
    
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
                    
                    // 可滚动的内容区域 - 设置灰色背景
                    ScrollView {
                        LazyVStack(spacing: Dimens.middleMargin) {
                            if isLoading {
                                ProgressView()
                                    .padding(.vertical, Dimens.largeMargin)
                            } else if directories.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(directories) { directory in
                                    // 目录卡片
                                    DirectoryCard(
                                        directory: directory,
                                        isSelected: selectedDirectoryId == directory.id,
                                        onSelect: {
                                            selectedDirectoryId = directory.id
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.middleMargin)
                    }
                    .background(Colors.pageBackgroundColor)  // 设置灰色背景
                    
                    // 底部操作区域
                    bottomActionView
                }
                .frame(
                    width: geometry.size.width,
                    height: min(geometry.size.height * 0.8, geometry.size.height - 100)
                )
                .background(Colors.whiteColor)
                .clipShape(RoundedCorner(radius: Dimens.borderRadius, corners: [.topLeft, .topRight]))
                .position(x: geometry.size.width / 2, y: geometry.size.height - (min(geometry.size.height * 0.8, geometry.size.height - 100) / 2))
            }
        }
        .onAppear {
            loadDirectories()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleFileSelection(url)
                } else {
                    alertMessage = "未选择文件"
                    showAlert = true
                }
            case .failure(let error):
                print("❌ 文件选择失败: \(error.localizedDescription)")
                alertMessage = "文件选择失败: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {
                if alertMessage.contains("成功") {
                    onUploadComplete()
                    isPresented = false
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        Text("上传文档")
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
    
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "folder")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            Text("暂无目录，请先创建目录")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .padding(.vertical, Dimens.largeMargin)
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
            Button(action: {
                showFilePicker = true
            }) {
                if isUploading {
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
            .background(selectedDirectoryId == nil ? Colors.grayColor : Colors.primaryColor)
            .cornerRadius(Dimens.btnHeight / 2)
            .disabled(selectedDirectoryId == nil || isUploading)
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
    
    /// 加载目录列表
    private func loadDirectories() {
        isLoading = true
        guard let tenantId = appState.currentTenant?.id else {
            isLoading = false
            return
        }
        
        HTTPClient.shared.getDirectoryList(tenantId: tenantId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let dirs):
                    directories = dirs
                case .failure(let error):
                    print("❌ 获取目录列表失败: \(error.localizedDescription)")
                    alertMessage = "获取目录列表失败"
                    showAlert = true
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - 文件处理方法
    
    /// 处理文件选择结果
    private func handleFileSelection(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "无法访问文件"
            showAlert = true
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let fileExtension = url.pathExtension.lowercased()
        let allowedExtensions = ["txt", "doc", "docx", "md"]
        
        guard allowedExtensions.contains(fileExtension) else {
            alertMessage = "请选择 .txt、.doc、.docx 或 .md 格式的文件"
            showAlert = true
            return
        }
        
        uploadFile(fileURL: url)
    }
    
    /// 上传文件
    private func uploadFile(fileURL: URL) {
        guard let tenantId = appState.currentTenant?.id,
              let directoryId = selectedDirectoryId else {
            alertMessage = "缺少必要参数"
            showAlert = true
            return
        }
        
        isUploading = true
        
        HTTPClient.shared.uploadDoc(
            fileURL: fileURL,
            tenantId: tenantId,
            directoryId: directoryId
        ) { result in
            DispatchQueue.main.async {
                isUploading = false
                
                switch result {
                case .success(let message):
                    print("✅ 文档上传成功")
                    alertMessage = message
                    showAlert = true
                    
                case .failure(let error):
                    print("❌ 文档上传失败: \(error.localizedDescription)")
                    alertMessage = "上传失败: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - 目录卡片组件

/// 目录卡片视图
struct DirectoryCard: View {
    let directory: Directory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // 目录图标
                Image(systemName: "folder.fill")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(isSelected ? Colors.primaryColor : Colors.grayColor)
                
                // 目录名称
                Text(directory.directory)
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
            .overlay(
                RoundedRectangle(cornerRadius: Dimens.borderRadius)
                    .stroke(isSelected ? Colors.primaryColor : Colors.grayColor.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    UploadDocumentDialog(
        isPresented: .constant(true),
        onUploadComplete: {}
    )
}