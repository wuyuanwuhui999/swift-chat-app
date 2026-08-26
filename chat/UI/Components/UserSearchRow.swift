//
//  UserSearchRow.swift
//  chat
//
//  Created by 吴文强 on 2026/6/25.
//

import SwiftUI

/// 用户搜索行视图（公共组件）
/// 用于「添加公司用户」/「添加租户用户」两个页面的搜索结果行，尾部三态：已添加 / 添加中 / 可添加
struct UserSearchRow: View {
    /// 搜索结果用户
    let user: SearchUserResult
    /// 是否已加入公司/租户（展示灰色「已添加」标签）
    let isAdded: Bool
    /// 是否正在添加中（展示 ProgressView）
    let isAdding: Bool
    /// 点击「添加」回调
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: Dimens.middleMargin) {
            // 用户头像
            UserAvatar(
                avatarUrl: user.avater,
                username: user.username,
                size: Dimens.middleAvater
            )

            // 用户信息
            VStack(alignment: .leading, spacing: Dimens.smallIcon) {
                Text(user.username)
                    .font(.system(size: Dimens.normalFont))
                    .foregroundColor(.black)

                Text(user.userAccount)
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
            }

            Spacer()

            // 添加按钮 / 已添加标签 / 加载状态
            if isAdded {
                Text("已添加")
                    .font(.system(size: Dimens.normalFont - 2))
                    .foregroundColor(Colors.grayColor)
                    .padding(.horizontal, Dimens.middleMargin)
                    .padding(.vertical, Dimens.smallMargin)
                    .background(Colors.grayColor.opacity(0.2))
                    .cornerRadius(Dimens.borderRadius * 2)
            } else if isAdding {
                // 加载状态
                ProgressView()
                    .frame(width: Dimens.middleIcon, height: Dimens.middleIcon)
            } else {
                Button(action: onAdd) {
                    Text("添加")
                        .font(.system(size: Dimens.normalFont))
                        .foregroundColor(Colors.whiteColor)
                        .padding(.horizontal, Dimens.middleMargin)
                        .padding(.vertical, Dimens.smallMargin)
                        .background(Colors.primaryColor)
                        .cornerRadius(Dimens.borderRadius * 2)
                }
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
}
