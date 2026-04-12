import SwiftUI

/// 聊天操作按钮组（深度思考、中英切换、查询文档）
struct ChatActionButtons: View {
    @Binding var showThink: Bool
    @Binding var language: String  // "zh" 或 "en"
    @Binding var showDocumentQuery: Bool  // 是否显示查询文档按钮激活状态
    
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
            
            // 查询文档按钮
            Button(action: {
                showDocumentQuery.toggle()
            }) {
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
        // 查询文档未激活状态
        ChatActionButtons(
            showThink: .constant(false),
            language: .constant("zh"),
            showDocumentQuery: .constant(false)
        )
        
        // 查询文档激活状态
        ChatActionButtons(
            showThink: .constant(true),
            language: .constant("en"),
            showDocumentQuery: .constant(true)
        )
    }
    .padding()
    .background(Colors.pageBackgroundColor)
}
