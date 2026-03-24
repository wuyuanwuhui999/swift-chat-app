//
//  Dimens.swift
//  chat
//
//  Created by 吴文强 on 2026/3/24.
//

import SwiftUI

struct Dimens {
    // 头像尺寸
    struct Avatar {
        static let small: CGFloat = 30
        static let middle: CGFloat = 50
        static let big: CGFloat = 100
    }
    
    // 图标尺寸
    struct Icon {
        static let small: CGFloat = 15
        static let middle: CGFloat = 25
        static let big: CGFloat = 50
    }
}

// 扩展CGFloat以便更方便使用
extension CGFloat {
    static let avatarSmall = Dimens.Avatar.small
    static let avatarMiddle = Dimens.Avatar.middle
    static let avatarBig = Dimens.Avatar.big
    
    static let iconSmall = Dimens.Icon.small
    static let iconMiddle = Dimens.Icon.middle
    static let iconBig = Dimens.Icon.big
}
