// ConversationService.swift
// 1カード → 1ターン の会話を個別生成する（JSON配列なし・シンプル設計）

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ConversationService {

    static let shared = ConversationService()
    private init() {}

    // MARK: - Public

    /// カード群から会話セッションを生成する（1カード = 1ターン を順番に生成）
    func generateSession(cards: [WordCard], turnCount: Int) async throws -> ConversationSession {
        guard !cards.isEmpty else { throw ConversationError.noCards }

        let selected = Array(cards.shuffled().prefix(min(turnCount, cards.count)))
        var turns: [ConversationTurn] = []

        for card in selected {
            let turn = try await generateOneTurn(card: card)
            turns.append(turn)
        }
        return ConversationSession(collectionTitle: "", turns: turns)
    }

    // MARK: - Private: 1カード → 1ターン

    private func generateOneTurn(card: WordCard) async throws -> ConversationTurn {
        let prompt = """
        Create a short, natural English conversation exchange.
        Speaker B must say EXACTLY this phrase: "\(card.english)"
        That phrase comes from this Japanese sentence: "\(card.japanese)"

        Output 4 lines in this exact format (no labels, no JSON, no extra text):
        LINE1: Speaker A's English sentence (leads B to naturally say the phrase)
        LINE2: Japanese translation of Speaker A's line
        LINE3: Japanese translation of Speaker B's reply (= "\(card.japanese)")
        LINE4: Speaker B's English reply (= "\(card.english)" used naturally)

        Example output:
        How are you feeling today?
        今日の調子はどう？
        まあまあかな。
        Not bad, I guess.

        Now output 4 lines only:
        """

        let raw = try await callFoundationModels(prompt: prompt)
        return try parseLines(raw: raw, card: card)
    }

    private func callFoundationModels(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let session = LanguageModelSession(
                instructions: "You are an English conversation writer. Output plain text only. No JSON, no markdown, no labels."
            )
            let response = try await session.respond(to: prompt)
            let raw = (response as? CustomStringConvertible)?.description ?? String(describing: response)

            // rawContent: "..." を取り出す
            if let range = raw.range(of: #"rawContent: \"(.*?)\""#, options: .regularExpression) {
                let segment = String(raw[range])
                let prefix = "rawContent: \""
                if segment.hasPrefix(prefix) && segment.hasSuffix("\"") {
                    return String(segment.dropFirst(prefix.count).dropLast())
                        .replacingOccurrences(of: "\\n", with: "\n")
                }
            }
            return raw.replacingOccurrences(of: "\\n", with: "\n")
        }
        #endif
        throw ConversationError.notAvailable
    }

    /// 4行テキストをパースして ConversationTurn を作る
    private func parseLines(raw: String, card: WordCard) throws -> ConversationTurn {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 4 else {
            throw ConversationError.parseError("4行取れませんでした(\(lines.count)行): \(raw.prefix(200))")
        }

        return ConversationTurn(
            partnerEnglish: lines[0],
            partnerJapanese: lines[1],
            myHintJapanese: lines[2],
            myEnglish: lines[3],
            usedCardIDs: [card.id]
        )
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
