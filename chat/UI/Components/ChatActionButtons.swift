import SwiftUI

/// 聊天操作按钮组（深度思考、中英切换、查询文档）
struct ChatActionButtons: View {
    @Binding var showThink: Bool
    @Binding var language: String  // "zh" 或 "en"
    @Binding var showDocumentQuery: Bool  // 是否显示查询文档按钮激活状态
    
    // 新增：文档数量（用于显示角标）
    var selectedDocCount: Int = 0
    // 新增：点击文档查询按钮的回调
    var onDocumentQueryToggle: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 深度思考按钮
            Button(action: {
                showThink.toggle()
            }) {
                Text("深度思考")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(showThink ? Colors.primaryColor : Colors.grayColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .frame(height: .smallBtnHeight)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                            .stroke(showThink ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
                    )
            }
            
            // 查询文档按钮 - 点击直接弹出文档选择器
            Button(action: {
                // 直接调用外部回调，弹出文档选择器
                onDocumentQueryToggle()
            }) {
                ZStack(alignment: .topTrailing) {
                    // 按钮文本
                    Text("查询文档")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(showDocumentQuery ? Colors.primaryColor : Colors.grayColor)
                        .padding(.horizontal, Dimens.middleMargin)
                        .frame(height: .smallBtnHeight)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                .stroke(showDocumentQuery ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
                        )
                    
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
            
            // 中英文切换按钮
            Button(action: {
                language = language == "zh" ? "en" : "zh"
            }) {
                Text(language == "zh" ? "中文" : "英文")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.primaryColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .frame(height: .smallBtnHeight)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                            .stroke(Colors.primaryColor, lineWidth: 1)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
        .background(Color.clear)
    }
}

#Preview {
    VStack(spacing: 20) {
        // 查询文档未激活状态（无角标）
        ChatActionButtons(
            showThink: .constant(false),
            language: .constant("zh"),
            showDocumentQuery: .constant(false),
            selectedDocCount: 0,
            onDocumentQueryToggle: {}
        )
        
        // 查询文档激活状态（有角标）
        ChatActionButtons(
            showThink: .constant(true),
            language: .constant("en"),
            showDocumentQuery: .constant(true),
            selectedDocCount: 3,
            onDocumentQueryToggle: {}
        )
        
        // 查询文档激活但无文档（无角标）
        ChatActionButtons(
            showThink: .constant(false),
            language: .constant("zh"),
            showDocumentQuery: .constant(true),
            selectedDocCount: 0,
            onDocumentQueryToggle: {}
        )
    }
    .padding()
    .background(Colors.pageBackgroundColor)
}