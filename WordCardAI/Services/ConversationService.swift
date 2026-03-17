// ConversationService.swift
// Apple Intelligence (FoundationModels) を使ってカードのフレーズを含む会話を生成する

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ConversationService {

    static let shared = ConversationService()
    private init() {}

    // MARK: - Public

    /// カード群から会話セッションを生成する
    /// - Parameters:
    ///   - cards: 使用するカード（日本語 + 英語フレーズ）
    ///   - turnCount: 生成するターン数（最大 cards.count に制限）
    func generateSession(cards: [WordCard], turnCount: Int) async throws -> ConversationSession {
        guard !cards.isEmpty else {
            throw ConversationError.noCards
        }

        // 使うカードをランダムで選ぶ（turnCountかcards.count の小さい方）
        let actualCount = min(turnCount, cards.count)
        let selectedCards = Array(cards.shuffled().prefix(actualCount))

        let turns = try await generateTurns(from: selectedCards)
        return ConversationSession(collectionTitle: "", turns: turns)
    }

    // MARK: - Private

    private func generateTurns(from cards: [WordCard]) async throws -> [ConversationTurn] {
        // カード情報をプロンプト用にまとめる
        let cardList = cards.enumerated().map { i, c in
            "\(i + 1). Japanese: \(c.japanese) / English: \(c.english)"
        }.joined(separator: "\n")

        let prompt = """
        You are an English conversation script writer.
        Create a natural English conversation where each of the following Japanese/English phrases is used EXACTLY ONCE as a response by Speaker B.

        Phrases to use:
        \(cardList)

        Rules:
        - For each phrase, write ONE conversation exchange (one turn).
        - Each turn must have:
          A) Speaker A's line in English (a natural question or statement that leads B to use the phrase)
          B) Speaker A's line in Japanese (translation of A's line)
          C) Speaker B's hint in Japanese (Japanese translation of the phrase — exactly the "Japanese" field above)
          D) Speaker B's answer in English (exactly the "English" field above, used naturally)
        - Output ONLY valid JSON. No explanation, no markdown, no code block.
        - Output format:
        [
          {
            "partnerEnglish": "...",
            "partnerJapanese": "...",
            "myHintJapanese": "...",
            "myEnglish": "...",
            "cardIndex": 0
          }
        ]
        - cardIndex is 0-based index into the phrases list above.
        - Keep A's lines short (1-2 sentences). Keep it realistic daily conversation.
        """

        let raw = try await callFoundationModels(prompt: prompt)
        return try parseJSON(raw: raw, cards: cards)
    }

    private func callFoundationModels(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let instructions = """
            You are a helpful English conversation script writer.
            Always respond with valid JSON only. No markdown, no code blocks, no explanation.
            """
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let raw = (response as? CustomStringConvertible)?.description ?? String(describing: response)

            // rawContent: "..." を取り出す
            if let range = raw.range(of: #"rawContent: \"(.*?)\""#, options: .regularExpression) {
                let segment = String(raw[range])
                let prefix = "rawContent: \""
                if segment.hasPrefix(prefix) && segment.hasSuffix("\"") {
                    let s = segment.dropFirst(prefix.count).dropLast()
                    return String(s).replacingOccurrences(of: "\\n", with: "\n")
                }
            }
            // rawContentが見つからなければそのまま返す
            return raw.replacingOccurrences(of: "\\n", with: "\n")
        }
        #endif
        throw ConversationError.notAvailable
    }

    private func parseJSON(raw: String, cards: [WordCard]) throws -> [ConversationTurn] {
        // JSON部分だけ抽出（[ から ] まで）
        guard let start = raw.firstIndex(of: "["),
              let end = raw.lastIndex(of: "]") else {
            throw ConversationError.parseError("JSON配列が見つかりません: \(raw.prefix(200))")
        }
        let jsonStr = String(raw[start...end])
        guard let data = jsonStr.data(using: .utf8) else {
            throw ConversationError.parseError("UTF8変換失敗")
        }

        struct RawTurn: Codable {
            let partnerEnglish: String
            let partnerJapanese: String
            let myHintJapanese: String
            let myEnglish: String
            let cardIndex: Int
        }

        let rawTurns = try JSONDecoder().decode([RawTurn].self, from: data)

        return rawTurns.map { rt in
            let cardID = (rt.cardIndex >= 0 && rt.cardIndex < cards.count)
                ? cards[rt.cardIndex].id
                : cards[0].id
            return ConversationTurn(
                partnerEnglish: rt.partnerEnglish,
                partnerJapanese: rt.partnerJapanese,
                myHintJapanese: rt.myHintJapanese,
                myEnglish: rt.myEnglish,
                usedCardIDs: [cardID]
            )
        }
    }
}

// MARK: - Errors

enum ConversationError: LocalizedError {
    case noCards
    case notAvailable
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noCards: return "カードがありません"
        case .notAvailable: return "Apple Intelligence が利用できません（iOS 18.2以降のApple Intelligence対応デバイスが必要です）"
        case .parseError(let msg): return "会話の生成に失敗しました: \(msg)"
        }
    }
}
