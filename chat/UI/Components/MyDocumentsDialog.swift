import SwiftUI

/// 我的文档对话框组件
/// 样式与「选择文档」对话框一致，但无复选框、无确定/取消按钮；
/// 文档条目右侧为「三个点」操作图标，提供修改权限与删除两个操作。
struct MyDocumentsDialog: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appState = AppState.shared
    @State private var directories: [Directory] = []
    @State private var isLoading = false
    @State private var expandedDirectories: Set<String> = []
    @State private var documentsByDirectory: [String: [Document]] = [:]
    @State private var loadingDirectories: Set<String> = []
    @State private var showCreateInput = false
    @State private var newDirectoryName = ""
    @State private var isCreating = false
    @FocusState private var isInputFocused: Bool

    // 页签状态：0=我的文档，1=公共文档
    @State private var selectedTab = 0
    @State private var publicDocuments: [Document] = []
    @State private var isLoadingPublic = false
    @State private var expandedPublicDirectories: Set<String> = []

    // 修改权限弹窗状态
    @State private var permissionTarget: Document? = nil
    @State private var isUpdatingPermission = false

    // 删除确认状态
    @State private var documentToDelete: Document? = nil

    // 操作结果提示
    @State private var showResultAlert = false
    @State private var resultMessage = ""

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
                                                documents: documentsByDirectory[directory.id],
                                                isLoadingDocs: loadingDirectories.contains(directory.id),
                                                onToggleExpand: { toggleDirectory(directory.id) },
                                                onModifyPermission: { requestModifyPermission($0) },
                                                onDeleteRequest: { documentToDelete = $0 }
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
                                // 公共文档页签：按 directoryName 分组展示（只读，无需加载）
                                if isLoadingPublic && publicDocuments.isEmpty {
                                    ProgressView()
                                        .padding(.vertical, Dimens.largeMargin)
                                } else if groupedPublicDocuments.isEmpty {
                                    publicEmptyStateView
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(Array(groupedPublicDocuments.enumerated()), id: \.offset) { index, group in
                                            PublicDirectoryCard(
                                                directoryName: group.name,
                                                documents: group.documents,
                                                isExpanded: expandedPublicDirectories.contains(group.name),
                                                onToggleExpand: { togglePublicDirectory(group.name) }
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

                    // 底部操作区域（仅创建目录，无确定/取消）
                    bottomActionView
                }
                .frame(
                    width: geometry.size.width,
                    height: min(geometry.size.height * 0.8, geometry.size.height - 100)
                )
                .background(Colors.whiteColor)
                .clipShape(RoundedCorner(radius: Dimens.borderRadius, corners: [.topLeft, .topRight]))
                .position(x: geometry.size.width / 2, y: geometry.size.height - (min(geometry.size.height * 0.8, geometry.size.height - 100) / 2))

                // 修改权限对话框
                if let document = permissionTarget {
                    DocumentPermissionDialog(
                        isPresented: Binding(
                            get: { permissionTarget != nil },
                            set: { if !$0 { permissionTarget = nil } }
                        ),
                        document: document,
                        isSubmitting: isUpdatingPermission,
                        onConfirm: { confirmUpdatePermission($0) }
                    )
                }
            }
        }
        .onAppear {
            loadDirectories()
        }
        .alert("确认删除", isPresented: Binding(
            get: { documentToDelete != nil },
            set: { if !$0 { documentToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                if let doc = documentToDelete {
                    confirmDelete(doc)
                }
            }
        } message: {
            Text("确定要删除文档「\(documentToDelete?.name ?? "")」吗？")
        }
        .alert("提示", isPresented: $showResultAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - 视图组件

    /// 标题栏视图（我的文档｜公共文档 两个可切换页签，居中，默认我的文档激活）
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: Dimens.middleMargin) {
                tabItem(title: "我的文档", index: 0)
                Text("|")
                    .foregroundColor(Colors.grayColor)
                    .font(.system(size: Dimens.normalFont))
                tabItem(title: "公共文档", index: 1)
            }
            .frame(maxWidth: .infinity)
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
            Text("请点击下方「创建目录」按钮")
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

    /// 底部操作区域视图（仅创建目录，无确定/取消按钮）
    @ViewBuilder
    private var bottomActionView: some View {
        VStack(spacing: Dimens.middleMargin) {
            // 创建目录（仅「我的文档」页签显示）
            if selectedTab == 0 {
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
            }
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

    /// 目录卡片视图（卡片式展示，样式与文档选择对话框一致）
    struct DirectoryCard: View {
        let directory: Directory
        let isExpanded: Bool
        let documents: [Document]?
        let isLoadingDocs: Bool
        let onToggleExpand: () -> Void
        let onModifyPermission: (Document) -> Void
        let onDeleteRequest: (Document) -> Void

        var body: some View {
            VStack(spacing: 0) {
                // 目录行（卡片头部）
                Button(action: onToggleExpand) {
                    HStack {
                        // 文件夹图标
                        Image(systemName: "folder")
                            .font(.system(size: Dimens.smallIcon))
                            .foregroundColor(Colors.primaryColor)

                        Text(directory.directory)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)

                        Spacer()

                        // 文档数量提示（收起时显示）
                        if let docs = documents, !docs.isEmpty, !isExpanded {
                            Text("\(docs.count)个文档")
                                .font(.system(size: Dimens.normalFont - 2))
                                .foregroundColor(Colors.grayColor)
                        }

                        // 展开箭头：向右，展开后顺时针旋转 90° 指向下
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
                        } else if let docs = documents, !docs.isEmpty {
                            ForEach(docs) { document in
                                DocumentRow(
                                    document: document,
                                    onModifyPermission: { onModifyPermission(document) },
                                    onDelete: { onDeleteRequest(document) }
                                )

                                if document.id != docs.last?.id {
                                    Divider()
                                        .padding(.leading, Dimens.middleMargin)
                                }
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("暂无文档")
                                    .font(.system(size: Dimens.normalFont))
                                    .foregroundColor(Colors.grayColor)
                                    .padding(.vertical, Dimens.middleMargin)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, Dimens.smallIcon)
                }
            }
        }
    }
    
    /// 文档行视图（无复选框、无文档格式标签，右侧为「三个点」操作图标）
    struct DocumentRow: View {
        let document: Document
        let onModifyPermission: () -> Void
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
            HStack(spacing: Dimens.middleMargin) {
                // 文件图标
                Image(systemName: fileIconName)
                    .font(.system(size: Dimens.smallIcon))
                    .foregroundColor(Colors.grayColor)

                // 文件名
                Text(document.name)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // 三个点操作图标：修改权限 / 删除
                Menu {
                    Button {
                        onModifyPermission()
                    } label: {
                        Label("修改权限", systemImage: "lock")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: Dimens.middleFont))
                        .foregroundColor(Colors.grayColor)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.smallIcon)
        }
    }

    /// 公共文档目录卡片视图（只读，按 directoryName 分组，文档已全部返回）
    struct PublicDirectoryCard: View {
        let directoryName: String
        let documents: [Document]
        let isExpanded: Bool
        let onToggleExpand: () -> Void

        var body: some View {
            VStack(spacing: 0) {
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

                if isExpanded {
                    Divider()
                        .padding(.horizontal, Dimens.middleMargin)

                    VStack(spacing: 0) {
                        ForEach(documents) { document in
                            PublicDocumentRow(document: document)
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

    /// 公共文档行视图（只读，无操作图标）
    struct PublicDocumentRow: View {
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
                    .font(.system(size: Dimens.smallIcon))
                    .foregroundColor(Colors.grayColor)

                // 文件名
                Text(document.name)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.smallIcon)
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

    /// 切换目录展开/收起状态（首次展开才加载文档列表）
    private func toggleDirectory(_ directoryId: String) {
        if expandedDirectories.contains(directoryId) {
            expandedDirectories.remove(directoryId)
        } else {
            expandedDirectories.insert(directoryId)
            if documentsByDirectory[directoryId] == nil {
                loadDocuments(directoryId: directoryId)
            }
        }
    }

    /// 加载指定目录下的文档列表
    private func loadDocuments(directoryId: String) {
        guard let tenantId = appState.currentTenant?.id else { return }
        loadingDirectories.insert(directoryId)

        HTTPClient.shared.getDocListByDirId(
            tenantId: tenantId,
            directoryId: directoryId
        ) { result in
            DispatchQueue.main.async {
                loadingDirectories.remove(directoryId)
                switch result {
                case .success(let docs):
                    documentsByDirectory[directoryId] = docs
                case .failure(let error):
                    documentsByDirectory[directoryId] = []
                    print("❌ 获取文档列表失败: \(error.localizedDescription)")
                }
            }
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

    // MARK: - 文档操作方法

    /// 弹出修改权限对话框
    private func requestModifyPermission(_ document: Document) {
        permissionTarget = document
    }

    /// 确认修改权限
    private func confirmUpdatePermission(_ newPermission: String) {
        guard let document = permissionTarget else { return }
        isUpdatingPermission = true

        HTTPClient.shared.updateDocPermission(
            docId: document.id,
            permission: newPermission
        ) { result in
            DispatchQueue.main.async {
                isUpdatingPermission = false
                switch result {
                case .success(let message):
                    // 本地同步该文档的权限，保证再次打开时回显正确
                    if var docs = documentsByDirectory[document.directoryId],
                       let idx = docs.firstIndex(where: { $0.id == document.id }) {
                        docs[idx].permission = newPermission
                        documentsByDirectory[document.directoryId] = docs
                    }
                    permissionTarget = nil
                    resultMessage = message
                    showResultAlert = true
                case .failure(let error):
                    resultMessage = error.localizedDescription
                    showResultAlert = true
                }
            }
        }
    }

    /// 确认删除文档
    private func confirmDelete(_ document: Document) {
        HTTPClient.shared.deleteDoc(docId: document.id) { result in
            DispatchQueue.main.async {
                documentToDelete = nil
                switch result {
                case .success(let message):
                    // 从本地列表移除
                    if var docs = documentsByDirectory[document.directoryId] {
                        docs.removeAll { $0.id == document.id }
                        documentsByDirectory[document.directoryId] = docs
                    }
                    resultMessage = message
                    showResultAlert = true
                case .failure(let error):
                    resultMessage = error.localizedDescription
                    showResultAlert = true
                }
            }
        }
    }
}

// MARK: - 文档权限选项

/// 文档权限选项（value 为提交值，label 为展示文案）
private struct PermissionOption: Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

// MARK: - 修改权限对话框

/// 修改权限对话框（回显文档当前权限，确定后提交）
struct DocumentPermissionDialog: View {
    @Binding var isPresented: Bool
    let document: Document
    let isSubmitting: Bool
    let onConfirm: (String) -> Void

    @State private var permission = "private"

    /// 权限选项（与上传接口的文档权限选项一致）
    private let permissionOptions: [PermissionOption] = [
        PermissionOption(value: "private", label: "私密"),
        PermissionOption(value: "tenant", label: "租户内公开"),
        PermissionOption(value: "company", label: "公司内公开")
    ]

    var body: some View {
        ZStack {
            // 半透明遮罩层
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isSubmitting {
                        isPresented = false
                    }
                }

            // 对话框卡片
            VStack(spacing: 0) {
                // 标题栏
                Text("修改权限")
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Dimens.middleMargin)
                    .overlay(
                        Rectangle()
                            .fill(Colors.grayColor.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )

                VStack(spacing: Dimens.middleMargin) {
                    // 文档名提示
                    Text(document.name)
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    // 权限下拉框
                    HStack(spacing: Dimens.middleMargin) {
                        Text("文档权限")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(.black)

                        Spacer()

                        Picker("", selection: $permission) {
                            ForEach(permissionOptions) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .tint(.black)
                    }
                    .frame(minHeight: Dimens.inputHeight)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)

                // 底部按钮
                HStack(spacing: Dimens.middleMargin) {
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
                    .disabled(isSubmitting)

                    Button(action: {
                        onConfirm(permission)
                    }) {
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
                    .background(Colors.primaryColor)
                    .cornerRadius(Dimens.btnHeight / 2)
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
            }
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
            .padding(.horizontal, Dimens.middleMargin * 2)
        }
        .onAppear {
            // 回显文档当前的权限字段
            permission = document.permission ?? "private"
        }
    }
}

#Preview {
    MyDocumentsDialog(
        isPresented: .constant(true)
    )
}
