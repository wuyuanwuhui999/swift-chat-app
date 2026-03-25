//
//  Dimens.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

struct Dimens {
    // 头像尺寸
    static let smallAvater: CGFloat = 30
    static let middleAvater: CGFloat = 50
    static let bigAvater: CGFloat = 100
    
    // 图标尺寸
    static let smallIcon: CGFloat = 15
    static let middleIcon: CGFloat = 25
    static let bigIcon: CGFloat = 50
    
    static let smallFont:CGFloat = 15
    static let middleFont:CGFloat = 20
    static let bigFont:CGFloat = 30
}

// 扩展CGFloat以便更方便使用
extension CGFloat {
    static let smallAvater = Dimens.smallAvater
    static let middleAvater = Dimens.middleAvater
    static let bigAvater = Dimens.bigAvater
    
    static let smallIcon = Dimens.smallIcon
    static let middleIcon = Dimens.middleIcon
    static let bigIcon = Dimens.bigIcon
    
    static let smallFont:CGFloat = Dimens.smallFont
    static let middleFont:CGFloat = Dimens.middleFont
    static let bigFont:CGFloat = Dimens.bigFont
}
