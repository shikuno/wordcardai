// ConversationScene.swift
// 1問分の会話シーン（1枚のカード = 1シーン）

import Foundation

/// 1問分の会話シーン
/// 流れ: 相手のセリフA → 自分（カードの英語） → 相手の続きB
struct ConversationScene: Identifiable {
    let id = UUID()
    let card: WordCard

    /// 相手の最初のセリフ（英語）
    let partnerOpeningEnglish: String
    /// 相手の最初のセリフ（日本語）
    let partnerOpeningJapanese: String

    /// 相手の続きのセリフ（英語）- 自分の返答を受けて
    let partnerReplyEnglish: String
    /// 相手の続きのセリフ（日本語）
    let partnerReplyJapanese: String
}
