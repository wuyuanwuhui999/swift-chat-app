import SwiftUI

/// 租户列表弹窗
struct TenantListPopup: View {
    @ObservedObject private var appState = AppState.shared
    @Binding var isPresented: Bool
    let onTenantSelected: (Tenant) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(appState.tenantList) { tenant in
                Button(action: {
                    onTenantSelected(tenant)
                    isPresented = false
                }) {
                    HStack {
                        Text(tenant.name)
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(isCurrentTenant(tenant) ? Colors.primaryColor : .primary)
                        Spacer()
                        if isCurrentTenant(tenant) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Colors.primaryColor)
                        }
                    }
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.middleMargin)
                }
                
                if tenant.id != appState.tenantList.last?.id {
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
    
    /// 判断是否为当前选中的租户
    private func isCurrentTenant(_ tenant: Tenant) -> Bool {
        return appState.currentTenant?.id == tenant.id
    }
}
