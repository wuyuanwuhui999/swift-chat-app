import SwiftUI

/// 模型列表弹窗
struct ModelListPopup: View {
    @ObservedObject private var appState = AppState.shared
    @Binding var isPresented: Bool
    let onModelSelected: (ChatModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(appState.modelList) { model in
                Button(action: {
                    onModelSelected(model)
                    isPresented = false
                }) {
                    HStack {
                        Text(model.modelName)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(isCurrentModel(model) ? Colors.primaryColor : .primary)
                        Spacer()
                        if isCurrentModel(model) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Colors.primaryColor)
                        }
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.middleMargin)
                }
                
                if model.id != appState.modelList.last?.id {
                    Divider()
                        .padding(.leading, Dimens.middleMargin)
                }
            }
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
        .shadow(radius: 5)
        .padding(.horizontal, Dimens.largeMargin)
    }
    
    /// 判断是否为当前选中的模型
    private func isCurrentModel(_ model: ChatModel) -> Bool {
        return appState.currentModel?.id == model.id
    }
}
