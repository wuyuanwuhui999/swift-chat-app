import SwiftUI

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .autocapitalization(.none)
            }
        }
        .font(.system(size: Dimens.normalFont))
        .padding(.horizontal, Dimens.middleMargin)
        .frame(height: Dimens.inputHeight)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: Dimens.inputHeight / 2)
                .stroke(isFocused ? Colors.primaryColor : Colors.grayColor, lineWidth: 1)
        )
    }
}
