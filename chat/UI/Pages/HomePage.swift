//
//  HomePage.swift
//  chat
//
//  Created by 吴文强 on 2026/3/27.
//
// UI/Pages/HomePage.swift
import SwiftUI

struct HomePage: View {
    @ObservedObject private var appState = AppState.shared
    
    var body: some View {
        ZStack {
            Colors.pageBackgroundColor
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Text("hellow swift")
                    .font(.system(size: Dimens.middleFont))
                    .foregroundColor(.themePrimary)
                
                Spacer()
            }
        }
        .navigationTitle("首页")
    }
}

#Preview {
    HomePage()
}
