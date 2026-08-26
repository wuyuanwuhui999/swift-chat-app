//
//  ChatModelType.swift
//  chat
//
//  Created by 吴文强 on 2026/7/7.
//

import Foundation

/// 大模型类型（取值与后端 chat_model.type 一致，只有 ollama / online 两种）
/// 页面状态仍用 String 存原始值，通过本枚举取展示文案与必填规则，避免各页重复维护映射表
enum ChatModelType: String, CaseIterable, Identifiable {
    /// 本地 ollama 模型
    case ollama
    /// 在线大模型
    case online

    var id: String { rawValue }

    /// 中文展示文案（Picker 展示用，提交仍用 rawValue）
    var displayName: String {
        switch self {
        case .ollama: return "ollama模型"
        case .online: return "在线模型"
        }
    }

    /// 是否必须填写 API Key（在线模型需要凭证，本地 ollama 不需要）
    var requiresApiKey: Bool {
        return self == .online
    }

    /// 取类型的中文展示文案，未知取值（如后端历史数据 deepseek）回退原始值
    /// - Parameter rawValue: 后端返回或页面持有的原始类型值
    static func displayName(for rawValue: String) -> String {
        return ChatModelType(rawValue: rawValue)?.displayName ?? rawValue
    }

    /// 该类型是否必须填写 API Key，未知取值按「不强制」处理
    /// - Parameter rawValue: 后端返回或页面持有的原始类型值
    static func requiresApiKey(for rawValue: String) -> Bool {
        return ChatModelType(rawValue: rawValue)?.requiresApiKey ?? false
    }
}
