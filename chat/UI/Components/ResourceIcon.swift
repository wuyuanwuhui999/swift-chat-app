import SwiftUI
import UIKit

/// 资源图标：优先使用 Resources 目录下的 PNG，缺失时回退到 SF Symbol。
/// 用法：ResourceIcon(resourceName: "icon_refresh", systemName: "arrow.clockwise")
struct ResourceIcon: View {
    let resourceName: String   // PNG 文件名（不含扩展名）
    let systemName: String     // 兜底 SF Symbol 名称
    var size: CGFloat = 22
    
    var body: some View {
        if let uiImage = UIImage(named: resourceName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
