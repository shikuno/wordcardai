// ConversationTurn.swift
// 会話練習1ターン分のデータ

import Foundation

/// 会話練習1ターン分
struct ConversationTurn: Identifiable {
    let id = UUID()

    /// 相手のセリフ（英語）
    let partnerEnglish: String
    /// 相手のセリフ（日本語訳）
    let partnerJapanese: String

    /// 自分の返答ヒント（日本語）
    let myHintJapanese: String
    /// 自分の返答（英語・正解）
    let myEnglish: String

    /// 使用しているカードのID（複数可）
    let usedCardIDs: [UUID]
}

/// 会話練習セッション全体
struct ConversationSession: Identifiable {
    let id = UUID()
    let collectionTitle: String
    let turns: [ConversationTurn]
    let createdAt: Date = .now
}
