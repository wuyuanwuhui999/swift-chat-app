import SwiftUI

/// 消息输入栏组件
struct MessageInputBar: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 左侧图标
            Image("icon_chat")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                .opacity(0.5)
            
            // 输入框
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .font(.system(size: Dimens.normalFont))
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.smallIcon)
                .background(Colors.pageBackgroundColor)
                .cornerRadius(Dimens.inputHeight / 2)
                .lineLimit(1...5)
            
            // 发送按钮
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
