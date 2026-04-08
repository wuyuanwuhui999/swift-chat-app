import SwiftUI

/// 我的文档对话框组件
struct MyDocumentsDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var directories: [Directory] = []
    @State private var isLoading = false
    @State private var expandedDirectories: Set<String> = []  // 展开的目录ID集合
    
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
                                    DirectoryExpandableSection(
                                        directory: directory,
                                        isExpanded: expandedDirectories.contains(directory.id),
                                        onToggleExpand: { toggleDirectory(directory.id) },
                                        onDocumentDeleted: { deletedDocId in
                                            // 文档删除后的回调，刷新当前目录的文档列表
                                            refreshDirectoryDocuments(directoryId: directory.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 底部关闭按钮
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
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        Text("我的文档")
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
            Text("暂无目录")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 底部操作区域视图
    @ViewBuilder
    private var bottomActionView: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 关闭按钮
            Button(action: {
                isPresented = false
            }) {
                Text("关闭")
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
                }
                isLoading = false
            }
        }
    }
    
    /// 切换目录展开/收起状态
    private func toggleDirectory(_ directoryId: String) {
        if expandedDirectories.contains(directoryId) {
            expandedDirectories.remove(directoryId)
        } else {
            expandedDirectories.insert(directoryId)
        }
    }
    
    /// 刷新指定目录的文档列表
    private func refreshDirectoryDocuments(directoryId: String) {
        // 重新加载该目录的文档列表
        if let index = directories.firstIndex(where: { $0.id == directoryId }) {
            // 触发该目录的文档重新加载
            // 这里通过重新展开目录来刷新
            if expandedDirectories.contains(directoryId) {
                // 先收起再展开，触发重新加载
                expandedDirectories.remove(directoryId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    expandedDirectories.insert(directoryId)
                }
            }
        }
    }
}

// MARK: - 可展开目录区域组件

/// 可展开目录区域视图
struct DirectoryExpandableSection: View {
    let directory: Directory
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDocumentDeleted: (String) -> Void  // 文档删除回调
    
    @State private var documents: [Document] = []
    @State private var isLoadingDocs = false
    @State private var showDeleteAlert = false
    @State private var documentToDelete: Document?  // 待删除的文档
    
    var body: some View {
        VStack(spacing: 0) {
            // 目录行
            Button(action: {
                onToggleExpand()
                if !isExpanded && documents.isEmpty {
                    loadDocuments()
                }
            }) {
                HStack {
                    Text(directory.directory)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 箭头图标（向右或向下）
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(Colors.grayColor)
                        .font(.system(size: Dimens.smallIcon))
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
            
            // 文档列表（展开时显示）
            if isExpanded {
                VStack(spacing: 0) {
                    if isLoadingDocs {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, Dimens.middleMargin)
                            Spacer()
                        }
                    } else if documents.isEmpty {
                        HStack {
                            Spacer()
                            Text("暂无文档")
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(Colors.grayColor)
                                .padding(.vertical, Dimens.middleMargin)
                            Spacer()
                        }
                    } else {
                        ForEach(documents) { document in
                            DocumentInfoRow(
                                document: document,
                                onDelete: {
                                    documentToDelete = document
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                .padding(.leading, Dimens.middleMargin)
                .background(Colors.pageBackgroundColor)
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                if let doc = documentToDelete {
                    deleteDocument(doc)
                }
            }
        } message: {
            Text("确定要删除文档 \"\(documentToDelete?.name ?? "")\" 吗？")
        }
    }
    
    /// 加载文档列表
    private func loadDocuments() {
        isLoadingDocs = true
        guard let tenantId = AppState.shared.currentTenant?.id else {
            isLoadingDocs = false
            return
        }
        
        HTTPClient.shared.getDocListByDirId(
            tenantId: tenantId,
            directoryId: directory.id
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let docs):
                    documents = docs
                case .failure(let error):
                    print("❌ 获取文档列表失败: \(error.localizedDescription)")
                }
                isLoadingDocs = false
            }
        }
    }
    
    /// 删除文档
    private func deleteDocument(_ document: Document) {
        HTTPClient.shared.deleteDoc(docId: document.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let deletedCount):
                    if deletedCount == 1 {
                        // 删除成功，从列表中移除
                        if let index = documents.firstIndex(where: { $0.id == document.id }) {
                            documents.remove(at: index)
                        }
                        // 显示成功提示
                        showSuccessAlert(message: "文档删除成功")
                        // 通知父组件文档已删除
                        onDocumentDeleted(document.id)
                    } else {
                        showSuccessAlert(message: "未找到要删除的文档")
                    }
                case .failure(let error):
                    print("❌ 删除文档失败: \(error.localizedDescription)")
                    showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    /// 显示成功提示
    private func showSuccessAlert(message: String) {
        // 使用 UIAlertController 显示提示
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    /// 显示错误提示
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - 文档信息行组件（支持滑动删除）

/// 文档信息行视图
struct DocumentInfoRow: View {
    let document: Document
    let onDelete: () -> Void
    
    /// 根据文件扩展名获取图标名称
    private var fileIconName: String {
        let ext = document.ext.lowercased()
        switch ext {
        case "txt":
            return "doc.plaintext"
        case "doc", "docx":
            return "doc"
        case "md":
            return "note.text"
        case "pdf":
            return "pdf"
        default:
            return "doc"
        }
    }
    
    var body: some View {
        // 使用 List 的滑动删除功能
        HStack(spacing: Dimens.middleMargin) {
            // 文件图标
            Image(systemName: fileIconName)
                .foregroundColor(Colors.primaryColor)
                .font(.system(size: Dimens.smallIcon))
            
            // 文件名
            Text(document.name)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // 文件类型标签
            Text(document.ext.uppercased())
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)
                .padding(.horizontal, Dimens.smallIcon)
                .padding(.vertical, 4)
                .background(Colors.grayColor.opacity(0.2))
                .cornerRadius(Dimens.smallIcon)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
        .background(Colors.pageBackgroundColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.2))
                .frame(height: 0.5),
            alignment: .bottom
        )
        // 添加滑动删除手势
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(Colors.warnColor)
        }
    }
}

#Preview {
    MyDocumentsDialog(
        isPresented: .constant(true)
    )
}
