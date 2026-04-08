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
                                        onToggleExpand: { toggleDirectory(directory.id) }
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
}

// MARK: - 可展开目录区域组件

/// 可展开目录区域视图
struct DirectoryExpandableSection: View {
    let directory: Directory
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    @State private var documents: [Document] = []
    @State private var isLoadingDocs = false
    
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
                            DocumentInfoRow(document: document)
                        }
                    }
                }
                .padding(.leading, Dimens.middleMargin)
                .background(Colors.pageBackgroundColor)
            }
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
}

// MARK: - 文档信息行组件

/// 文档信息行视图
struct DocumentInfoRow: View {
    let document: Document
    
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
    }
}

#Preview {
    MyDocumentsDialog(
        isPresented: .constant(true)
    )
}
