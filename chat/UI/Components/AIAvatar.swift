import SwiftUI

/// AI头像组件
/// 支持自定义大小，内置图片加载失败降级方案
struct AIAvatar: View {
    /// 头像大小
    let size: CGFloat
    /// 头像形状（圆形或方形）
    var shape: AvatarShape = .square
    /// 背景颜色（降级方案使用）
    var backgroundColor: Color = Colors.primaryColor.opacity(0.7)
    /// 降级图标
    var fallbackIcon: String = "cpu.fill"
    /// 内容填充模式
    var contentMode: ContentMode = .fit
    
    /// 头像形状枚举
    enum AvatarShape {
        case circle    // 圆形
        case square    // 方形/矩形
    }
    
    init(
        size: CGFloat,
        shape: AvatarShape = .square,
        backgroundColor: Color = Colors.primaryColor.opacity(0.7),
        fallbackIcon: String = "cpu.fill",
        contentMode: ContentMode = .fit
    ) {
        self.size = size
        self.shape = shape
        self.backgroundColor = backgroundColor
        self.fallbackIcon = fallbackIcon
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let logoImage = UIImage(named: "logo") {
                // 加载真实图片
                Image(uiImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: size, height: size)
                    .applyShape(shape: shape)
            } else {
                // 降级方案：显示图标占位符
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .applyShape(shape: shape)
                    .overlay(
                        Image(systemName: fallbackIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size * 0.5, height: size * 0.5)
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - View Extension for Shape
extension View {
    @ViewBuilder
    func applyShape(shape: AIAvatar.AvatarShape) -> some View {
        switch shape {
        case .circle:
            self.clipShape(Circle())
        case .square:
            self.clipShape(Rectangle())
        }
    }
}

// MARK: - 便捷初始化方法
extension AIAvatar {
    /// 小尺寸方形头像
    static func smallSquare() -> AIAvatar {
        AIAvatar(
            size: Dimens.smallAvater,
            shape: .square
        )
    }
    
    /// 中尺寸方形头像
    static func middleSquare() -> AIAvatar {
        AIAvatar(
            size: Dimens.middleAvater,
            shape: .square
        )
    }
    
    /// 大尺寸方形头像
    static func largeSquare() -> AIAvatar {
        AIAvatar(
            size: Dimens.bigAvater,
            shape: .square
        )
    }
    
    /// 小尺寸圆形头像
    static func smallCircle() -> AIAvatar {
        AIAvatar(
            size: Dimens.smallAvater,
            shape: .circle
        )
    }
    
    /// 中尺寸圆形头像
    static func middleCircle() -> AIAvatar {
        AIAvatar(
            size: Dimens.middleAvater,
            shape: .circle
        )
    }
    
    /// 大尺寸圆形头像
    static func largeCircle() -> AIAvatar {
        AIAvatar(
            size: Dimens.bigAvater,
            shape: .circle
        )
    }
    
    // MARK: - 兼容旧方法
    /// 兼容旧代码：大尺寸（默认方形）
    static func large() -> AIAvatar {
        return largeSquare()
    }
    
    /// 兼容旧代码：中尺寸（默认方形）
    static func middle() -> AIAvatar {
        return middleSquare()
    }
    
    /// 兼容旧代码：小尺寸（默认方形）
    static func small() -> AIAvatar {
        return smallSquare()
    }
}

// MARK: - 预览
#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // MARK: - 方形头像示例（直角）
            Text("方形头像（直角）")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                AIAvatar.smallSquare()
                Text("小方形 (30x30)")
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                AIAvatar.middleSquare()
                Text("中方形 (50x50)")
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                AIAvatar.largeSquare()
                Text("大方形 (80x80)")
                    .font(.caption)
            }
            
            Divider()
                .padding(.vertical)
            
            // MARK: - 圆形头像示例
            Text("圆形头像")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                AIAvatar.smallCircle()
                Text("小圆形 (30x30)")
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                AIAvatar.middleCircle()
                Text("中圆形 (50x50)")
                    .font(.caption)
            }
            
            HStack(spacing: 20) {
                AIAvatar.largeCircle()
                Text("大圆形 (80x80)")
                    .font(.caption)
            }
            
            Divider()
                .padding(.vertical)
            
            // MARK: - 自定义样式示例
            Text("自定义样式")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                // 自定义颜色和图标
                AIAvatar(
                    size: 60,
                    shape: .square,
                    backgroundColor: .blue.opacity(0.7),
                    fallbackIcon: "brain"
                )
                Text("蓝色背景")
                    .font(.caption)
                
                // 填充模式为 .fill
                AIAvatar(
                    size: 60,
                    shape: .square,
                    backgroundColor: .green.opacity(0.7),
                    fallbackIcon: "cpu",
                    contentMode: .fill
                )
                Text("fill模式")
                    .font(.caption)
                
                // 圆形自定义
                AIAvatar(
                    size: 60,
                    shape: .circle,
                    backgroundColor: .orange.opacity(0.7),
                    fallbackIcon: "person.fill"
                )
                Text("圆形")
                    .font(.caption)
            }
            
            Divider()
                .padding(.vertical)
            
            // MARK: - 兼容旧方法测试
            Text("兼容旧方法（默认方形）")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                AIAvatar.small()
                AIAvatar.middle()
                AIAvatar.large()
            }
        }
        .padding()
        .background(Colors.pageBackgroundColor)
    }
}
