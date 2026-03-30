import SwiftUI

/// 自定义三角形形状，用于消息气泡箭头
struct Triangle: Shape {
    /// 三角形方向：left 表示向左，right 表示向右
    var direction: TriangleDirection
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch direction {
        case .left:
            // 箭头指向左边的三角形（从右向左）
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .right:
            // 箭头指向右边的三角形（从左向右）
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        
        return path
    }
}

enum TriangleDirection {
    case left
    case right
}

/// 聊天消息气泡组件
struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: Dimens.middleMargin) {
            if message.isUser {
                // 用户消息：头像在右边，文字在左边
                Spacer(minLength: 0)
                
                // 用户消息内容容器（用于对齐三角形）
                VStack(alignment: .trailing, spacing: Dimens.smallIcon) {
                    // 使用富文本解析
                    MessageContentView(content: message.content, isUser: true, alignToAvatar: true)
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                }
                .overlay(
                    // 三角形箭头指向右边，与头像居中对齐
                    GeometryReader { geometry in
                        Triangle(direction: .right)
                            .fill(Colors.whiteColor)
                            .frame(width: 16, height: 16)
                            .position(
                                x: geometry.size.width + 8,
                                y: geometry.size.height / 2 - 8
                            )
                    }
                )
                
                // 用户头像
                if let userData = appState.userData {
                    UserAvatar(
                        avatarUrl: userData.avater,
                        username: userData.username,
                        size: Dimens.middleAvater
                    )
                } else {
                    // 占位头像
                    Circle()
                        .fill(Colors.grayColor)
                        .frame(width: Dimens.middleAvater, height: Dimens.middleAvater)
                }
            } else {
                // AI消息：头像在左边，文字在右边
                // AI头像（使用logo）
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Dimens.middleAvater, height: Dimens.middleAvater)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.grayColor, lineWidth: 1))
                
                // AI消息内容容器（用于对齐三角形）
                VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                    // 使用富文本解析
                    MessageContentView(content: message.content, isUser: false, alignToAvatar: true)
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: Dimens.normalFont - 2))
                        .foregroundColor(Colors.grayColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    // 三角形箭头指向左边，与头像居中对齐
                    GeometryReader { geometry in
                        Triangle(direction: .left)
                            .fill(Colors.whiteColor)
                            .frame(width: 16, height: 16)
                            .position(
                                x: -8,
                                y: geometry.size.height / 2 - 8
                            )
                    }
                )
                
                Spacer(minLength: 0)
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

/// 消息内容视图（支持解析<think>标签）
struct MessageContentView: View {
    let content: String
    let isUser: Bool
    let alignToAvatar: Bool  // 是否对齐到头像（用于三角形定位）
    
    var body: some View {
        if isUser {
            // 用户消息：消息框在左边，三角形在右边指向头像
            Text(content)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.black)
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
                .background(Colors.whiteColor)
                .cornerRadius(Dimens.borderRadius)
        } else {
            // AI消息：需要解析思考内容，消息框在右边，三角形在左边指向头像
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                let parsed = parseContent(content)
                
                if let thinkContent = parsed.think, !thinkContent.isEmpty {
                    // 思考内容
                    VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                        HStack {
                            Image(systemName: "brain")
                                .font(.system(size: Dimens.smallIcon))
                            Text("思考过程")
                                .font(.system(size: Dimens.normalFont - 2))
                        }
                        .foregroundColor(Colors.grayColor)
                        
                        Text(thinkContent)
                            .font(.system(size: Dimens.normalFont - 2))
                            .foregroundColor(Colors.grayColor)
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.smallIcon)
                    .background(Colors.grayColor.opacity(0.1))
                    .cornerRadius(Dimens.borderRadius)
                }
                
                if let bodyContent = parsed.body, !bodyContent.isEmpty {
                    Text(bodyContent)
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, Dimens.middleMargin)
            .padding(.vertical, Dimens.middleMargin)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
        }
    }
    
    /// 解析内容，分离思考内容和正文
    private func parseContent(_ content: String) -> (think: String?, body: String?) {
        guard content.hasPrefix("<think>") else {
            return (nil, content)
        }
        
        var thinkContent: String?
        var bodyContent: String?
        
        if let endRange = content.range(of: "</think>") {
            let thinkStart = content.index(content.startIndex, offsetBy: 7) // "<think>".count
            let thinkEnd = endRange.lowerBound
            thinkContent = String(content[thinkStart..<thinkEnd])
            
            let bodyStart = content.index(endRange.upperBound, offsetBy: 0)
            if bodyStart < content.endIndex {
                bodyContent = String(content[bodyStart...])
            }
        } else {
            // 如果没有结束标签，整个内容作为思考内容
            thinkContent = String(content.dropFirst(7))
        }
        
        return (thinkContent, bodyContent)
    }
}

#Preview {
    VStack(spacing: 20) {
        // 用户消息示例
        MessageBubble(message: ChatMessage(content: "你好，这是一条用户消息，这条消息比较长，用来测试三角形的对齐效果", isUser: true))
        
        // AI消息示例
        MessageBubble(message: ChatMessage(content: "你好！我是AI助手，很高兴为你服务。这是一条AI回复消息，用来测试三角形的对齐效果", isUser: false))
        
        // 带思考过程的AI消息示例
        MessageBubble(message: ChatMessage(content: "<think>用户发送了问候消息，我需要友好回应，这是一段比较长的思考过程，用来测试三角形在长文本中的对齐效果</think>你好！有什么我可以帮助你的吗？", isUser: false))
    }
    .padding()
    .background(Colors.pageBackgroundColor)
}
