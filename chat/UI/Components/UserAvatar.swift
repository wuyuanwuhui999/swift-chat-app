import SwiftUI

/// 用户头像组件
struct UserAvatar: View {
    let avatarUrl: String?
    let username: String
    let size: CGFloat
    
    var body: some View {
        Group {
            if let avatarUrl = avatarUrl, !avatarUrl.isEmpty {
                // 网络图片头像
                AsyncImage(url: URL(string: Constants.baseURL + avatarUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        // 加载失败显示文字头像
                        textAvatar
                    @unknown default:
                        textAvatar
                    }
                }
            } else {
                // 文字头像（取用户名第一个字）
                textAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    /// 文字头像视图
    private var textAvatar: some View {
        ZStack {
            Colors.primaryColor
                .opacity(0.7)
            
            Text(getFirstCharacter())
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    /// 获取用户名的第一个字符
    private func getFirstCharacter() -> String {
        guard let firstChar = username.first else {
            return "?"
        }
        return String(firstChar)
    }
}

#Preview {
    VStack(spacing: 20) {
        UserAvatar(avatarUrl: nil, username: "张三", size: Dimens.middleAvater)
        UserAvatar(avatarUrl: "/avatar/test.jpg", username: "李四", size: Dimens.middleAvater)
        UserAvatar(avatarUrl: nil, username: "王", size: Dimens.middleAvater)
    }
    .padding()
}
