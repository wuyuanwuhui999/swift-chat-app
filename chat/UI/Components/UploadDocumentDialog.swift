// UI/Components/UploadDocumentDialog.swift

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
                    
                    // 可滚动的内容区域
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if isLoading {
                                ProgressView()
                                    .padding(.vertical, Dimens.largeMargin)
                            } else if directories.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(directories) { directory in
                                    DirectoryRadioRow(
                                        directory: directory,
                                        isSelected: selectedDirectoryId == directory.id,
                                        onSelect: {
                                            selectedDirectoryId = directory.id
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
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
            allowedContentTypes: [.plainText, .text], // .txt 文件
            allowsMultipleSelection: false
        ) { result in
            // 修复：处理 Result<[URL], Error> 类型，因为 allowsMultipleSelection: false 时返回的是数组
            switch result {
            case .success(let urls):
                // 取第一个选中的文件
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
        // 获取文件访问权限
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "无法访问文件"
            showAlert = true
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // 检查文件格式（支持 .txt, .doc, .docx, .md）
        let fileExtension = url.pathExtension.lowercased()
        let allowedExtensions = ["txt", "doc", "docx", "md"]
        
        guard allowedExtensions.contains(fileExtension) else {
            alertMessage = "请选择 .txt、.doc、.docx 或 .md 格式的文件"
            showAlert = true
            return
        }
        
        // 上传文件
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

/// 目录单选行视图
struct DirectoryRadioRow: View {
    let directory: Directory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(directory.directory)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 单选按钮
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Colors.primaryColor : Colors.grayColor)
                    .font(.system(size: Dimens.middleIcon))
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
        }
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#Preview {
    UploadDocumentDialog(
        isPresented: .constant(true),
        onUploadComplete: {}
    )
}
