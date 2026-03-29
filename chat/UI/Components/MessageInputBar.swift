// UI/Components/MessageInputBar.swift
import SwiftUI

/// 消息输入栏组件
struct MessageInputBar: View {
    @Binding var messageText: String
    let isSending: Bool  // 是否正在发送
    let onSend: () -> Void
    let onClear: () -> Void  // 清空聊天
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 左侧清空按钮
            Button(action: onClear) {
                Image(systemName: "plus.message")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                    .foregroundColor(Colors.grayColor)
            }
            
            // 输入框
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .font(.system(size: Dimens.normalFont))
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.smallIcon)
                .background(Colors.pageBackgroundColor)
                .cornerRadius(Dimens.inputHeight / 2)
                .lineLimit(1...5)
                .disabled(isSending)  // 发送中禁用输入框
            
            // 发送按钮
            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Colors.grayColor))
                        .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                } else {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                        .foregroundColor(messageText.isEmpty ? Colors.grayColor : Colors.primaryColor)
                }
            }
            .disabled(messageText.isEmpty || isSending)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
        .background(Colors.whiteColor)
    }
}

#Preview {
    MessageInputBar(messageText: .constant("测试消息"), isSending: false, onSend: {}, onClear: {})
        .padding()
        .background(Colors.pageBackgroundColor)
}
