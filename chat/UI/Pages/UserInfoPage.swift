//
//  UserInfoPage.swift
//  chat
//
//  Created by 吴文强 on 2026/6/13.
//

import SwiftUI

/// 用户信息详情页面
struct UserInfoPage: View {
    @Environment(\.dismiss) private var dismiss
    let companyUser: CompanyUser
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            customNavigationBar
            
            // 内容区域（灰色背景）
            ScrollView {
                VStack(spacing: Dimens.middleMargin) {
                    // 用户信息卡片
                    userInfoCard
                }
                .padding(.horizontal, Dimens.middleMargin)
                .padding(.top, Dimens.middleMargin)
                .padding(.bottom, Dimens.middleMargin)
            }
            .background(Colors.pageBackgroundColor)
        }
        .background(Colors.pageBackgroundColor)
        .navigationBarHidden(true)
    }
    
    // MARK: - 视图组件
    
    /// 自定义导航栏
    private var customNavigationBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(Colors.primaryColor)
            }
            
            Spacer()
            
            // 标题
            Text("用户信息")
                .font(.system(size: Dimens.middleFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 占位按钮，保持标题居中
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Dimens.middleIcon))
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
        .background(Colors.whiteColor)
        .overlay(
            Rectangle()
                .fill(Colors.grayColor.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    /// 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 0) {
            // 头像行
            avatarRow
            
            DividerLine()
            
            // 姓名
            infoRow(label: "姓名", value: companyUser.username)
            
            DividerLine()
            
            // 工号
            infoRow(label: "工号", value: companyUser.userAccount)
            
            DividerLine()
            
            // 角色
            infoRow(label: "角色", value: companyUser.roleText)
            
            DividerLine()
            
            // 电话
            infoRow(label: "电话", value: companyUser.telephone.isEmpty ? "未设置" : companyUser.telephone)
            
            DividerLine()
            
            // 邮箱
            infoRow(label: "邮箱", value: companyUser.email.isEmpty ? "未设置" : companyUser.email)
            
            DividerLine()
            
            // 性别
            infoRow(label: "性别", value: getGenderText(companyUser.sex))
            
            DividerLine()
            
            // 部门
            infoRow(label: "部门", value: companyUser.displayDepartment)
            
            DividerLine()
            
            // 职位
            infoRow(label: "职位", value: companyUser.displayPosition)
            
            DividerLine()
            
            // 地区
            infoRow(label: "地区", value: companyUser.region?.isEmpty == false ? companyUser.region! : "未设置")
            
            DividerLine()
            
            // 个性签名
            infoRow(label: "个性签名", value: companyUser.sign.isEmpty ? "未设置" : companyUser.sign)
            
            DividerLine()
            
            // 加入时间（只显示年月日）
            infoRow(label: "加入时间", value: formatJoinDate(companyUser.joinDate))
        }
        .background(Colors.whiteColor)
        .cornerRadius(Dimens.borderRadius)
    }
    
    /// 头像行视图
    private var avatarRow: some View {
        HStack {
            Text("头像")
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 头像显示
            Group {
                if let avatarUrl = companyUser.avater, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: Constants.baseURL + avatarUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                                .clipShape(Circle())
                        case .failure:
                            defaultAvatarView
                        @unknown default:
                            defaultAvatarView
                        }
                    }
                } else {
                    defaultAvatarView
                }
            }
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
    
    /// 默认头像视图
    private var defaultAvatarView: some View {
        ZStack {
            Colors.primaryColor.opacity(0.7)
                .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
                .clipShape(Circle())
            
            Text(getFirstCharacter())
                .font(.system(size: Dimens.bigAvater * 0.4))
                .foregroundColor(.white)
        }
        .frame(width: Dimens.bigAvater, height: Dimens.bigAvater)
    }
    
    /// 信息行视图
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.system(size: Dimens.normalFont))
                .foregroundColor(value == "未设置" ? Colors.grayColor : .primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
        .padding(.horizontal, Dimens.middleMargin)
        .padding(.vertical, Dimens.middleMargin)
    }
    
    /// 分割线
    private func DividerLine() -> some View {
        Rectangle()
            .fill(Colors.grayColor.opacity(0.3))
            .frame(height: 1)
            .padding(.leading, Dimens.middleMargin)
    }
    
    // MARK: - 辅助方法
    
    /// 获取用户名的第一个字符
    private func getFirstCharacter() -> String {
        guard let firstChar = companyUser.username.first else {
            return "?"
        }
        return String(firstChar)
    }
    
    /// 获取性别文本
    private func getGenderText(_ sex: String) -> String {
        switch sex {
        case "0":
            return "男"
        case "1":
            return "女"
        default:
            return "未设置"
        }
    }
    
    /// 格式化加入时间（只显示年月日）
    private func formatJoinDate(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "未设置"
        }
        
        // 尝试解析 ISO 8601 格式（带时分秒）
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.timeZone = TimeZone.current
        
        // 尝试解析标准格式（带时分秒）
        let standardFormatter = DateFormatter()
        standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        standardFormatter.locale = Locale(identifier: "en_US_POSIX")
        standardFormatter.timeZone = TimeZone.current
        
        // 尝试解析纯日期格式（不带时分秒）
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.timeZone = TimeZone.current
        
        var date: Date?
        
        if let parsedDate = isoFormatter.date(from: dateString) {
            date = parsedDate
        } else if let parsedDate = standardFormatter.date(from: dateString) {
            date = parsedDate
        } else if let parsedDate = dateOnlyFormatter.date(from: dateString) {
            date = parsedDate
        }
        
        if let validDate = date {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            return displayFormatter.string(from: validDate)
        }
        
        return dateString
    }
}

#Preview {
    UserInfoPage(companyUser: CompanyUser(
        id: "1",
        userId: "user123",
        userAccount: "emp001",
        username: "张三",
        telephone: "13800138000",
        email: "zhangsan@example.com",
        sex: "0",
        region: "北京市朝阳区",
        avater: nil,
        sign: "代码改变世界",
        companyId: "company001",
        positionId: "pos001",
        positionName: "高级工程师",
        departmentId: "dept001",
        departmentName: "技术部",
        role: 1,
        joinDate: "2024-01-15T10:30:00",
        status: 1,
        createBy: "admin",
        createDate: "2024-01-15T10:30:00",
        updateDate: nil,
        birthday: nil,
        password: nil,
        disabled: nil,
        permission: nil
    ))
}