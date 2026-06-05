import SwiftUI

/// 文档选择对话框组件
struct DocumentPickerDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var directories: [Directory] = []
    @State private var isLoading = false
    @State private var expandedDirectories: Set<String> = []
    @State private var selectedDocIds: Set<String> = []
    @State private var showCreateInput = false
    @State private var newDirectoryName = ""
    @State private var isCreating = false
    @FocusState private var isInputFocused: Bool
    
    let onConfirm: (Set<String>) -> Void
    
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
                    
                    // 可滚动的内容区域 - 灰色背景
                    ScrollView {
                        LazyVStack(spacing: Dimens.middleMargin) {
                            if isLoading {
                                ProgressView()
                                    .padding(.vertical, Dimens.largeMargin)
                            } else if directories.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(directories) { directory in
                                    // 每个目录作为一张卡片
                                    DirectoryCard(
                                        directory: directory,
                                        isExpanded: expandedDirectories.contains(directory.id),
                                        selectedDocIds: selectedDocIds,
                                        onToggleExpand: { toggleDirectory(directory.id) },
                                        onToggleDocument: { toggleDocument($0) }
                                    )
                                }
                            }
                        }
                        .padding(Dimens.middleMargin)
                    }
                    .background(Colors.pageBackgroundColor)
                    
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
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        VStack(spacing: 0) {
            Text("查询文档")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Dimens.middleMargin)
            
            // 灰色分隔线
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1)
        }
        .background(Colors.whiteColor)
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
            Text("请点击下方「创建目录」按钮")
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 底部操作区域视图
    @ViewBuilder
    private var bottomActionView: some View {
        VStack(spacing: Dimens.middleMargin) {
            if showCreateInput {
                // 创建目录输入框
                HStack(spacing: Dimens.middleMargin) {
                    TextField("请输入目录名称", text: $newDirectoryName)
                        .font(.system(size: Dimens.normalFont))
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Colors.pageBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                                .stroke(isInputFocused ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
                        )
                        .focused($isInputFocused)
                    
                    // 确认按钮
                    Button(action: createDirectory) {
                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Dimens.smallIcon, height: Dimens.smallIcon)
                            .foregroundColor(.white)
                            .frame(width: Dimens.inputHeight, height: Dimens.inputHeight)
                            .background(newDirectoryName.isEmpty ? Colors.grayColor : Colors.primaryColor)
                            .clipShape(Circle())
                    }
                    .disabled(newDirectoryName.isEmpty || isCreating)
                    
                    // 取消按钮
                    Button(action: {
                        showCreateInput = false
                        newDirectoryName = ""
                    }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Dimens.smallIcon, height: Dimens.smallIcon)
                            .foregroundColor(.white)
                            .frame(width: Dimens.inputHeight, height: Dimens.inputHeight)
                            .background(Colors.grayColor)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, Dimens.middleMargin)
            } else {
                // 创建按钮
                Button(action: {
                    showCreateInput = true
                    isInputFocused = true
                }) {
                    Text("创建目录")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(Colors.primaryColor)
                        .cornerRadius(Dimens.btnHeight / 2)
                }
                .padding(.horizontal, Dimens.middleMargin)
            }
            
            // 确定和取消按钮
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
                    onConfirm(selectedDocIds)
                    isPresented = false
                }) {
                    Text("确定")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.white)
                        .frame(height: Dimens.btnHeight)
                        .frame(maxWidth: .infinity)
                        .background(selectedDocIds.isEmpty ? Colors.grayColor : Colors.primaryColor)
                        .cornerRadius(Dimens.btnHeight / 2)
                }
                .disabled(selectedDocIds.isEmpty)
            }
            .padding(.horizontal, Dimens.middleMargin)
        }
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - 目录卡片组件
    
    /// 目录卡片视图（卡片式展示）
    struct DirectoryCard: View {
        let directory: Directory
        let isExpanded: Bool
        let selectedDocIds: Set<String>
        let onToggleExpand: () -> Void
        let onToggleDocument: (Document) -> Void
        
        @State private var documents: [Document] = []
        @State private var isLoadingDocs = false
        
        var body: some View {
            VStack(spacing: 0) {
                // 目录行（卡片头部）
                Button(action: {
                    onToggleExpand()
                    if !isExpanded && documents.isEmpty {
                        loadDocuments()
                    }
                }) {
                    HStack {
                        // 文件夹图标
                        Image(systemName: "folder")
                            .font(.system(size: Dimens.smallIcon))
                            .foregroundColor(Colors.primaryColor)
                        
                        Text(directory.directory)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 文档数量提示（如果有文档）
                        if !documents.isEmpty && !isExpanded {
                            Text("\(documents.count)个文档")
                                .font(.system(size: Dimens.normalFont - 2))
                                .foregroundColor(Colors.grayColor)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(Colors.grayColor)
                            .font(.system(size: Dimens.smallIcon))
                    }
                    .padding(Dimens.middleMargin)
                }
                
                // 文档列表（展开时显示）
                if isExpanded {
                    Divider()
                        .padding(.horizontal, Dimens.middleMargin)
                    
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
                                DocumentRow(
                                    document: document,
                                    isSelected: selectedDocIds.contains(document.id),
                                    onToggle: { onToggleDocument(document) }
                                )
                                
                                if document.id != documents.last?.id {
                                    Divider()
                                        .padding(.leading, Dimens.middleMargin)
                                }
                            }
                        }
                    }
                    .padding(.vertical, Dimens.smallIcon)
                }
            }
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Dimens.borderRadius)
                    .stroke(Colors.grayColor.opacity(0.2), lineWidth: 0.5)
            )
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
    
    /// 文档行视图
    struct DocumentRow: View {
        let document: Document
        let isSelected: Bool
        let onToggle: () -> Void
        
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
            Button(action: onToggle) {
                HStack(spacing: Dimens.middleMargin) {
                    // 文件图标
                    Image(systemName: fileIconName)
                        .font(.system(size: Dimens.smallIcon))
                        .foregroundColor(Colors.grayColor)
                    
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
                    
                    // 选中图标
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: Dimens.smallIcon))
                        .foregroundColor(isSelected ? Colors.primaryColor : Colors.grayColor)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.smallIcon)
            }
        }
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
    
    /// 切换文档选中状态
    private func toggleDocument(_ document: Document) {
        if selectedDocIds.contains(document.id) {
            selectedDocIds.remove(document.id)
        } else {
            selectedDocIds.insert(document.id)
        }
    }
    
    /// 创建目录
    private func createDirectory() {
        guard !newDirectoryName.isEmpty,
              let tenantId = appState.currentTenant?.id else { return }
        
        isCreating = true
        
        HTTPClient.shared.createDirectory(
            directory: newDirectoryName,
            tenantId: tenantId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newDirectory):
                    directories.append(newDirectory)
                    showCreateInput = false
                    newDirectoryName = ""
                case .failure(let error):
                    print("❌ 创建目录失败: \(error.localizedDescription)")
                }
                isCreating = false
            }
        }
    }
}

/// 圆角裁剪形状（支持指定角）
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    DocumentPickerDialog(
        isPresented: .constant(true),
        onConfirm: { _ in }
    )
}