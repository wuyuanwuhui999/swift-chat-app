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
        ZStack(alignment: .top) {
            // 半透明遮罩层
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // 对话框内容
            VStack(spacing: 0) {
                // 标题栏
                headerView
                
                // 目录和文档列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(directories) { directory in
                            DirectorySection(
                                directory: directory,
                                isExpanded: expandedDirectories.contains(directory.id),
                                selectedDocIds: selectedDocIds,
                                onToggleExpand: { toggleDirectory(directory.id) },
                                onToggleDocument: { toggleDocument($0) }
                            )
                        }
                    }
                    .padding(.vertical, Dimens.middleMargin)
                }
                .frame(maxHeight: .infinity)
                
                // 底部操作区域
                bottomActionView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Colors.whiteColor)
            .clipShape(RoundedCorner(radius: Dimens.borderRadius, corners: [.topLeft, .topRight]))
            .offset(y: UIScreen.main.bounds.height * 0.2)
            .frame(height: UIScreen.main.bounds.height * 0.8)
        }
        .onAppear {
            loadDirectories()
        }
    }
    
    // MARK: - 视图组件
    
    /// 标题栏视图
    private var headerView: some View {
        Text("选择文档")
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
        VStack(spacing: Dimens.middleMargin) {
            if showCreateInput {
                // 创建目录输入框
                HStack(spacing: Dimens.middleMargin) {
                    TextField("请输入目录名称", text: $newDirectoryName)
                        .font(.system(size: Dimens.normalFont))
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: Dimens.inputHeight)
                        .background(Color.white)
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
                    Text("创建")
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
                        .foregroundColor(Colors.blackColor)
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
            .padding(.bottom, Dimens.middleMargin)
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
    
    // MARK: - 目录区域组件
    
    /// 目录区域视图
    struct DirectorySection: View {
        let directory: Directory
        let isExpanded: Bool
        let selectedDocIds: Set<String>
        let onToggleExpand: () -> Void
        let onToggleDocument: (Document) -> Void
        
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
                        
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(Colors.grayColor)
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.middleMargin)
                }
                
                // 文档列表
                if isExpanded {
                    VStack(spacing: 0) {
                        if isLoadingDocs {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        } else {
                            ForEach(documents) { document in
                                DocumentRow(
                                    document: document,
                                    isSelected: selectedDocIds.contains(document.id),
                                    onToggle: { onToggleDocument(document) }
                                )
                            }
                        }
                    }
                    .padding(.leading, Dimens.middleMargin)
                }
            }
            .background(Colors.whiteColor)
            .overlay(
                Rectangle()
                    .fill(Colors.grayColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        
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
        
        var body: some View {
            Button(action: onToggle) {
                HStack {
                    Text(document.name)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? Colors.primaryColor : Colors.grayColor)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
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
