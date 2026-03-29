import SwiftUI

/// 消息输入栏组件
struct MessageInputBar: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 左侧图标 - 使用系统图标作为备选
            Group {
                Image(systemName: "plus.message")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                    .foregroundColor(Colors.grayColor)
            }
            
            // 输入框 - 按照规范设置圆角和背景
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .font(.system(size: Dimens.normalFont))
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.smallIcon)
                .background(Colors.pageBackgroundColor)
                .cornerRadius(Dimens.inputHeight / 2) // 圆角为高度的一半
                .lineLimit(1...5)
            
            // 发送按钮 - 符合设计规范
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                    .foregroundColor(messageText.isEmpty ? Colors.grayColor : Colors.primaryColor)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
        .background(Colors.whiteColor)
    }
}

#Preview {
    MessageInputBar(messageText: .constant("测试消息"), onSend: {})
        .padding()
        .background(Colors.pageBackgroundColor)
}
