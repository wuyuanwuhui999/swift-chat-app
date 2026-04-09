import SwiftUI

/// 通用自定义对话框组件
struct CustomDialog<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let content: Content
    let onConfirm: () -> Void
    var onCancel: (() -> Void)?
    
    init(
        isPresented: Binding<Bool>,
        title: String,
        @ViewBuilder content: () -> Content,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.title = title
        self.content = content()
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    onCancel?()
                }
            
            VStack(spacing: Dimens.middleMargin) {
                // 标题
                Text(title)
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.primary)
                    .padding(.top, Dimens.middleMargin)
                
                // 内容区域
                content
                    .padding(.horizontal, Dimens.middleMargin)
                
                // 按钮区域
                HStack(spacing: Dimens.middleMargin) {
                    // 取消按钮
                    Button(action: {
                        isPresented = false
                        onCancel?()
                    }) {
                        Text("取消")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.grayColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                    .stroke(Colors.grayColor, lineWidth: 1)
                            )
                    }
                    
                    // 确定按钮
                    Button(action: onConfirm) {
                        Text("确定")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.whiteColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Colors.primaryColor)
                            .cornerRadius(Dimens.btnHeight / 2)
                    }
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.bottom, Dimens.middleMargin)
            }
            .frame(width: UIScreen.main.bounds.width - Dimens.largeMargin * 4)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
        }
    }
}

/// 选择列表对话框组件
struct CustomSelectionDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let options: [String]
    @State var selectedIndex: Int
    let onConfirm: (Int) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // 标题
                Text(title)
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.primary)
                    .padding(.vertical, Dimens.middleMargin)
                    .frame(maxWidth: .infinity)
                    .background(Colors.whiteColor)
                    .overlay(
                        Rectangle()
                            .fill(Colors.grayColor.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                
                // 选项列表
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectedIndex = index
                    }) {
                        HStack {
                            Text(option)
                                .font(.system(size: Dimens.normalFont))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedIndex == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Colors.primaryColor)
                            }
                        }
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.middleMargin)
                    }
                    
                    if index != options.count - 1 {
                        Rectangle()
                            .fill(Colors.grayColor.opacity(0.3))
                            .frame(height: 1)
                            .padding(.leading, Dimens.middleMargin)
                    }
                }
                
                // 按钮区域
                HStack(spacing: Dimens.middleMargin) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("取消")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.grayColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                    .stroke(Colors.grayColor, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        onConfirm(selectedIndex)
                        isPresented = false
                    }) {
                        Text("确定")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.whiteColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Colors.primaryColor)
                            .cornerRadius(Dimens.btnHeight / 2)
                    }
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.vertical, Dimens.middleMargin)
            }
            .frame(width: UIScreen.main.bounds.width - Dimens.largeMargin * 4)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
        }
    }
}

/// 日期选择对话框组件
struct CustomDatePickerDialog: View {
    @Binding var isPresented: Bool
    let title: String
    @State var selectedDate: Date
    let onConfirm: (Date) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: Dimens.middleMargin) {
                // 标题
                Text(title)
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.primary)
                    .padding(.top, Dimens.middleMargin)
                
                // 日期选择器
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, Dimens.middleMargin)
                
                // 按钮区域
                HStack(spacing: Dimens.middleMargin) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("取消")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.grayColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: Dimens.btnHeight / 2)
                                    .stroke(Colors.grayColor, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        onConfirm(selectedDate)
                        isPresented = false
                    }) {
                        Text("确定")
                            .font(.system(size: Dimens.normalFont))
                            .foregroundColor(Colors.whiteColor)
                            .frame(height: Dimens.btnHeight)
                            .frame(maxWidth: .infinity)
                            .background(Colors.primaryColor)
                            .cornerRadius(Dimens.btnHeight / 2)
                    }
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.bottom, Dimens.middleMargin)
            }
            .frame(width: UIScreen.main.bounds.width - Dimens.largeMargin * 4)
            .background(Colors.whiteColor)
            .cornerRadius(Dimens.borderRadius)
        }
    }
}
