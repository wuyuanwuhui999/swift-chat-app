// chat/chat/UI/Components/ChatActionButtons.swift
import SwiftUI

/// 聊天操作按钮组（深度思考、中英切换、查询文档、提示词）
/// 支持水平滚动，确保所有按钮文字完整显示
struct ChatActionButtons: View {
    @Binding var showThink: Bool
    @Binding var language: String  // "zh" 或 "en"
    @Binding var showDocumentQuery: Bool  // 是否显示查询文档按钮激活状态
    @Binding var showPromptActive: Bool  // 提示词按钮是否激活
    
    // 文档数量（用于显示角标）
    var selectedDocCount: Int = 0
    // 点击文档查询按钮的回调
    var onDocumentQueryToggle: () -> Void
    // 点击提示词按钮的回调
    var onPromptToggle: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Dimens.middleMargin) {
                // 深度思考按钮
                actionButton(
                    title: "深度思考",
                    isActive: showThink,
                    activeColor: Colors.primaryColor
                ) {
                    showThink.toggle()
                }
                
                // 查询文档按钮
                documentQueryButton
                
                // 提示词按钮
                actionButton(
                    title: "提示词",
                    isActive: showPromptActive,
                    activeColor: Colors.primaryColor
                ) {
                    onPromptToggle()
                }
                
                // 中英文切换按钮
                languageToggleButton
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.smallIcon)
        }
        .background(Color.clear)
        .frame(height: Dimens.smallBtnHeight + Dimens.middleMargin * 2)
    }
    
    // MARK: - 按钮组件
    
    /// 通用操作按钮
    /// - Parameters:
    ///   - title: 按钮标题
    ///   - isActive: 是否激活状态
    ///   - activeColor: 激活状态颜色
    ///   - action: 点击回调
    private func actionButton(
        title: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(isActive ? activeColor : Colors.grayColor)
                .padding(.horizontal, Dimens.middleMargin)
                .frame(height: Dimens.smallBtnHeight)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                        .stroke(isActive ? activeColor : Colors.grayColor, lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)  // 防止文字换行
        }
    }
    
    /// 查询文档按钮（带角标）
    private var documentQueryButton: some View {
        Button(action: onDocumentQueryToggle) {
            ZStack(alignment: .topTrailing) {
                Text("查询文档")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(showDocumentQuery ? Colors.primaryColor : Colors.grayColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .frame(height: Dimens.smallBtnHeight)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                            .stroke(showDocumentQuery ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
                    )
                    .fixedSize(horizontal: true, vertical: false)  // 防止文字换行
                
                // 角标：当文档查询激活且选中文档数量 > 0 时显示
                if showDocumentQuery && selectedDocCount > 0 {
                    Text("\(selectedDocCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(minWidth: Dimens.middleIcon - 10, minHeight: Dimens.middleIcon - 10)
                        .padding(.horizontal, 4)
                        .background(Colors.primaryColor)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
    }
    
    /// 语言切换按钮
    private var languageToggleButton: some View {
        Button(action: {
            language = language == "zh" ? "en" : "zh"
        }) {
            Text(language == "zh" ? "中文" : "英文")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(Colors.primaryColor)
                .padding(.horizontal, Dimens.middleMargin)
                .frame(height: Dimens.smallBtnHeight)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                        .stroke(Colors.primaryColor, lineWidth: 1)
                )
                .fixedSize(horizontal: true, vertical: false)  // 防止文字换行
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        // 未激活状态
        ChatActionButtons(
            showThink: .constant(false),
            language: .constant("zh"),
            showDocumentQuery: .constant(false),
            showPromptActive: .constant(false),
            selectedDocCount: 0,
            onDocumentQueryToggle: {},
            onPromptToggle: {}
        )
        .padding()
        .background(Colors.pageBackgroundColor)
        
        // 激活状态（有角标）
        ChatActionButtons(
            showThink: .constant(true),
            language: .constant("en"),
            showDocumentQuery: .constant(true),
            showPromptActive: .constant(true),
            selectedDocCount: 3,
            onDocumentQueryToggle: {},
            onPromptToggle: {}
        )
        .padding()
        .background(Colors.pageBackgroundColor)
        
        // 激活状态（无角标）
        ChatActionButtons(
            showThink: .constant(false),
            language: .constant("zh"),
            showDocumentQuery: .constant(true),
            showPromptActive: .constant(true),
            selectedDocCount: 0,
            onDocumentQueryToggle: {},
            onPromptToggle: {}
        )
        .padding()
        .background(Colors.pageBackgroundColor)
    }
}