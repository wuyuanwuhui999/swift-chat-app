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
    
    // 页签状态：0=我的文档，1=公共文档
    @State private var selectedTab = 0
    @State private var publicDocuments: [Document] = []
    @State private var isLoadingPublic = false
    @State private var expandedPublicDirectories: Set<String> = []
    
    let onConfirm: (Set<String>) -> Void
    let onCancel: (() -> Void)?  // 取消回调
    let onUpload: (() -> Void)?  // 上传文档回调
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 半透明遮罩层
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel?()
                        isPresented = false
                    }
                
                // 对话框内容 - 从底部弹出
                VStack(spacing: 0) {
                    // 标题栏
                    headerView
                    
                    // 可滚动的内容区域 - 灰色背景
                    ScrollView {
                        LazyVStack(spacing: Dimens.middleMargin) {
                            if selectedTab == 0 {
                                // 我的文档页签（原逻辑）
                                if isLoading {
                                    ProgressView()
                                        .padding(.vertical, Dimens.largeMargin)
                                } else if directories.isEmpty {
                                    emptyStateView
                                } else {
                                    // 所有目录放入一张卡片，目录间用灰色横线隔开
                                    VStack(spacing: 0) {
                                        ForEach(Array(directories.enumerated()), id: \.element.id) { index, directory in
                                            DirectoryCard(
                                                directory: directory,
                                                isExpanded: expandedDirectories.contains(directory.id),
                                                selectedDocIds: selectedDocIds,
                                                onToggleExpand: { toggleDirectory(directory.id) },
                                                onToggleDocument: { toggleDocument($0) }
                                            )
                                            if index < directories.count - 1 {
                                                Divider()
                                            }
                                        }
                                    }
                                    .background(Colors.whiteColor)
                                    .cornerRadius(Dimens.borderRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Dimens.borderRadius)
                                            .stroke(Colors.grayColor.opacity(0.2), lineWidth: 0.5)
                                    )
                                }
                            } else {
                                // 公共文档页签：按 directoryName 分组展示（已全部返回，无需按目录加载）
                                if isLoadingPublic && publicDocuments.isEmpty {
                                    ProgressView()
                                        .padding(.vertical, Dimens.largeMargin)
                                } else if groupedPublicDocuments.isEmpty {
                                    publicEmptyStateView
                                } else {
                                    // 所有分组放入一张卡片，分组间用灰色横线隔开
                                    VStack(spacing: 0) {
                                        ForEach(Array(groupedPublicDocuments.enumerated()), id: \.offset) { index, group in
                                            PublicDirectoryCard(
                                                directoryName: group.name,
                                                documents: group.documents,
                                                isExpanded: expandedPublicDirectories.contains(group.name),
                                                selectedDocIds: selectedDocIds,
                                                onToggleExpand: { togglePublicDirectory(group.name) },
                                                onToggleDocument: { toggleDocument($0) }
                                            )
                                            if index < groupedPublicDocuments.count - 1 {
                                                Divider()
                                            }
                                        }
                                    }
                                    .background(Colors.whiteColor)
                                    .cornerRadius(Dimens.borderRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Dimens.borderRadius)
                                            .stroke(Colors.grayColor.opacity(0.2), lineWidth: 0.5)
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
    
    /// 标题栏视图（左：刷新；中：我的文档｜公共文档页签；右：创建目录+上传）
    private var headerView: some View {
        VStack(spacing: 0) {
            ZStack {
                // 居中页签
                HStack(spacing: Dimens.middleMargin) {
                    tabItem(title: "我的文档", index: 0)
                    Text("|")
                        .foregroundColor(Colors.grayColor)
                        .font(.system(size: Dimens.normalFont))
                    tabItem(title: "公共文档", index: 1)
                }
                
                // 左侧：刷新图标
                HStack {
                    Button(action: refresh) {
                        ResourceIcon(resourceName: "icon_refresh", systemName: "arrow.clockwise")
                    }
                    .padding(.leading, Dimens.middleMargin)
                    Spacer()
                }
                
                // 右侧：创建目录 + 上传
                HStack {
                    Spacer()
                    Button(action: {
                        selectedTab = 0
                        showCreateInput = true
                        isInputFocused = true
                    }) {
                        ResourceIcon(resourceName: "icon_create_directory", systemName: "folder.badge.plus")
                    }
                    Button(action: {
                        onUpload?()
                    }) {
                        ResourceIcon(resourceName: "icon_upload", systemName: "square.and.arrow.up")
                    }
                    .padding(.leading, Dimens.middleMargin)
                    .padding(.trailing, Dimens.middleMargin)
                }
            }
            .padding(.vertical, Dimens.middleMargin)
            
            // 灰色分隔线
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1)
        }
        .background(Colors.whiteColor)
    }
    
    /// 单个页签（激活态高亮，未激活态黑色）
    private func tabItem(title: String, index: Int) -> some View {
        let isActive = selectedTab == index
        return Button(action: {
            selectedTab = index
            if index == 1 {
                loadPublicDocuments()
            }
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: Dimens.middleFont, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Colors.primaryColor : .black)
                // 激活指示条
                Rectangle()
                    .fill(isActive ? Colors.primaryColor : Color.clear)
                    .frame(width: 40, height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
            Text("请点击右上角「创建目录」图标")
                .font(.system(size: Dimens.normalFont - 2))
                .foregroundColor(Colors.grayColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 公共文档空状态视图
    private var publicEmptyStateView: some View {
        VStack(spacing: Dimens.middleMargin) {
            Image(systemName: "folder")
                .font(.system(size: Dimens.bigIcon))
                .foregroundColor(Colors.grayColor)
            Text("暂无公开文档")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.grayColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Dimens.largeMargin)
    }
    
    /// 底部操作区域视图
    @ViewBuilder
    private var bottomActionView: some View {
        VStack(spacing: Dimens.middleMargin) {
            // 创建目录输入框（仅「我的文档」页签且点击创建图标后显示）
            if selectedTab == 0 && showCreateInput {
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
            }
            
            // 确定和取消按钮
            HStack(spacing: Dimens.middleMargin) {
                // 取消按钮
                Button(action: {
                    onCancel?()  // 调用取消回调
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
            .padding(.vertical, Dimens.middleMargin)
            .background(Colors.whiteColor)
            .overlay(
                Rectangle()
                    .fill(Colors.grayColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .top
            )
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
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        // 文档数量提示（如果有文档）
                        if !documents.isEmpty && !isExpanded {
                            Text("\(documents.count)个文档")
                                .font(.system(size: Dimens.normalFont - 2))
                                .foregroundColor(Colors.grayColor)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Colors.grayColor)
                            .font(.system(size: Dimens.smallIcon))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
                        .foregroundColor(.black)
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
    
    /// 公共文档目录卡片视图（按 directoryName 分组，文档已全部返回，展开直接展示，无需加载）
    struct PublicDirectoryCard: View {
        let directoryName: String
        let documents: [Document]
        let isExpanded: Bool
        let selectedDocIds: Set<String>
        let onToggleExpand: () -> Void
        let onToggleDocument: (Document) -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                // 目录行（卡片头部）
                Button(action: onToggleExpand) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: Dimens.smallIcon))
                            .foregroundColor(Colors.primaryColor)
                        
                        Text(directoryName)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if !isExpanded {
                            Text("\(documents.count)个文档")
                                .font(.system(size: Dimens.normalFont - 2))
                                .foregroundColor(Colors.grayColor)
                        }
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(Colors.grayColor)
                            .font(.system(size: Dimens.smallIcon))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    .padding(Dimens.middleMargin)
                }
                
                // 文档列表（展开时显示，已全部加载，无需请求）
                if isExpanded {
                    Divider()
                        .padding(.horizontal, Dimens.middleMargin)
                    
                    VStack(spacing: 0) {
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
                    .padding(.vertical, Dimens.smallIcon)
                }
            }
        }
    }
    
    // MARK: - 数据加载方法
    
    /// 刷新当前页签数据
    private func refresh() {
        if selectedTab == 0 {
            loadDirectories()
        } else {
            loadPublicDocuments()
        }
    }
    
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
    
    /// 公共文档按 directoryName 分组（保持首次出现顺序）
    private var groupedPublicDocuments: [(name: String, documents: [Document])] {
        var order: [String] = []
        var groups: [String: [Document]] = [:]
        for doc in publicDocuments {
            let key = doc.directoryName ?? "未分类"
            if groups[key] == nil {
                order.append(key)
                groups[key] = [doc]
            } else {
                groups[key]?.append(doc)
            }
        }
        return order.map { (name: $0, documents: groups[$0] ?? []) }
    }
    
    /// 加载公开文档列表（tenantId + companyId）
    private func loadPublicDocuments() {
        guard !isLoadingPublic else { return }
        guard let tenantId = appState.currentTenant?.id,
              let companyId = appState.currentCompany?.id ?? appState.getCachedCompanyId() else {
            return
        }
        
        isLoadingPublic = true
        
        HTTPClient.shared.getPublicDocList(tenantId: tenantId, companyId: companyId) { result in
            DispatchQueue.main.async {
                isLoadingPublic = false
                switch result {
                case .success(let docs):
                    publicDocuments = docs
                case .failure(let error):
                    print("❌ 获取公开文档列表失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 切换公共文档目录（分组）展开/收起状态
    private func togglePublicDirectory(_ directoryName: String) {
        if expandedPublicDirectories.contains(directoryName) {
            expandedPublicDirectories.remove(directoryName)
        } else {
            expandedPublicDirectories.insert(directoryName)
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
        onConfirm: { _ in },
        onCancel: { },
        onUpload: { }
    )
}