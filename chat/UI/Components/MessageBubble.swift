import SwiftUI

/// 聊天消息气泡组件
struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: Dimens.middleMargin) {
            if message.isUser {
                Spacer(minLength: 60)
                
                // 用户消息内容
                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                    Text(message.content)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.middleMargin)
                        .background(Colors.whiteColor)
                        .cornerRadius(Dimens.borderRadius)
                        .overlay(
                            // 小三角形
                            Triangle()
                                .fill(Colors.whiteColor)
                                .frame(width: 10, height: 10)
                                .offset(x: 5, y: 15),
                            alignment: .trailing
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                }
                
                // 用户头像
                if let userData = appState.userData {
                    UserAvatar(
                        avatarUrl: userData.avater,
                        username: userData.username,
                        size: Dimens.middleAvater
                    )
                }
            } else {
                // AI消息内容
                VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                    Text(message.content)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.middleMargin)
                        .background(Colors.whiteColor)
                        .cornerRadius(Dimens.borderRadius)
                        .overlay(
                            // 小三角形
                            Triangle()
                                .fill(Colors.whiteColor)
                                .frame(width: 10, height: 10)
                                .offset(x: -5, y: 15),
                            alignment: .leading
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.smallIcon)
    }
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

/// 三角形形状
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
