import SwiftUI

/// 文档选择按钮组件（显示在消息输入栏右侧）
struct DocumentSelectionButton: View {
    let selectedCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Image(systemName: "doc.text")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
                    .foregroundColor(selectedCount > 0 ? Colors.primaryColor : Colors.grayColor)
                
                // 右上角角标
                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Colors.primaryColor)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
            .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        DocumentSelectionButton(selectedCount: 0, onTap: {})
        DocumentSelectionButton(selectedCount: 3, onTap: {})
    }
    .padding()
}
