//
//  Colors.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

struct Colors {
    // 主色调
    static let primaryColor = Color(red: 255/255, green: 174/255, blue: 0/255)
    
    // 灰色，用于小标题、禁用按钮、提示文字、禁用文字
    static let grayColor = Color(red: 221/255, green: 221/255, blue: 221/255)
    
    // 白色
    static let whiteColor = Color.white
    
    static let blackColor = Color.black;
    
    // 页面背景颜色
    static let pageBackgroundColor = Color(red: 239/255, green: 239/255, blue: 239/255)
}

// 扩展Color以便更方便使用
extension Color {
    static let themePrimary = Colors.primaryColor
    static let themeGray = Colors.grayColor
    static let themeWhite = Colors.whiteColor
    static let themeBackground = Colors.pageBackgroundColor
    static let blackColor = Colors.blackColor
}
