//
//  MainView.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        ZStack {
            // 设置背景颜色
            Color.themeBackground
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 中间显示文字
                Text("Hellow SwiftUI")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.themePrimary)
                    .padding()
                
                Spacer()
            }
        }
        .navigationTitle("Chat")
    }
}

#Preview {
    MainView()
}
