import SwiftUI

/// 聊天页面标题栏组件
struct ChatHeader: View {
    @ObservedObject private var appState = AppState.shared
    @Binding var showTenantList: Bool
    @Binding var showModelList: Bool
    let onMenuClick: () -> Void
    
    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 左侧用户头像
            if let userData = appState.userData {
                UserAvatar(
                    avatarUrl: userData.avater,
                    username: userData.username,
                    size: Dimens.middleAvater
                )
            } else {
                // 占位符
                Circle()
                    .fill(Colors.grayColor)
                    .frame(width: Dimens.middleAvater, height: Dimens.middleAvater)
            }
            
            // 中间标题区域 - 租户名称和模型名称分开
            HStack() {
                // 租户名称按钮
                Button(action: {
                    showTenantList.toggle()
                    showModelList = false
                }) {
                    Text(appState.currentTenant?.name ?? "选择租户")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                        .lineLimit(1) // 限制为一行
                }
                
                // 分隔符
                Text("｜")
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(Colors.grayColor)
                
                // 模型名称按钮 - 不换行，超出显示省略号
                Button(action: {
                    showModelList.toggle()
                    showTenantList = false
                }) {
                    Text(appState.currentModel?.modelName ?? "选择模型")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(.primary)
                        .lineLimit(1) // 限制为一行
                        .truncationMode(.tail) // 超出部分尾部显示省略号
                }
            }
            .frame(maxWidth: .infinity) // 占满剩余空间
            
            // 右侧菜单图标
            Button(action: onMenuClick) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.primaryColor)
            }
        }
        .padding(.horizontal, .middleMargin) // 去掉左右外边距
        .padding(.vertical, .middleMargin)
        .background(Colors.whiteColor)
    }
}
