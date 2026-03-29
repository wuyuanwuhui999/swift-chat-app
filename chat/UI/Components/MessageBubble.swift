// UI/Components/MessageBubble.swift
import SwiftUI

/// 自定义三角形形状，用于消息气泡箭头
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

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
                    // 使用富文本解析
                    MessageContentView(content: message.content, isUser: true)
                    
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
                // AI头像（使用logo）
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Dimens.middleAvater, height: Dimens.middleAvater)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Colors.grayColor, lineWidth: 1))
                
                // AI消息内容
                VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                    // 使用富文本解析
                    MessageContentView(content: message.content, isUser: false)
                    
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

/// 消息内容视图（支持解析<think>标签）
struct MessageContentView: View {
    let content: String
    let isUser: Bool
    
    var body: some View {
        if isUser {
            // 用户消息不需要解析
            Text(content)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.black)
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
                .background(Colors.whiteColor)
                .cornerRadius(Dimens.borderRadius)
                .overlay(
                    Triangle()
                        .fill(Colors.whiteColor)
                        .frame(width: 10, height: 10)
                        .offset(x: 5, y: 15),
                    alignment: .trailing
                )
        } else {
            // AI消息需要解析思考内容
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
            .overlay(
                Triangle()
                    .fill(Colors.whiteColor)
                    .frame(width: 10, height: 10)
                    .offset(x: -5, y: 15),
                alignment: .leading
            )
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
