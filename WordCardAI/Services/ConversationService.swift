// ConversationService.swift
// 1枚のカード → 1つの会話シーンを生成

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ConversationService {
    static let shared = ConversationService()
    private init() {}

    /// 1枚のカードから会話シーンを1つ生成する
    func generateScene(for card: WordCard) async throws -> ConversationScene {
        let prompt = """
        Create a short, natural 3-line English conversation.
        The middle line (Speaker B) must be EXACTLY: "\(card.english)"

        Output exactly 4 lines in this order (no labels, no numbers, no JSON):
        Line 1: Speaker A's opening sentence in English
        Line 2: Japanese translation of Line 1
        Line 3: Speaker A's reply after hearing "\(card.english)", in English
        Line 4: Japanese translation of Line 3

        Rules:
        - Keep all lines short (1 sentence each)
        - Make it natural daily conversation
        - Do NOT include Speaker B's line in the output

        Example for "Not bad, I guess.":
        How are you feeling today?
        今日の調子はどう？
        That's good to hear!
        それは良かった！
        """

        let raw = try await callFoundationModels(prompt: prompt)
        return try parseScene(raw: raw, card: card)
    }

    // MARK: - Private

    private func callFoundationModels(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let session = LanguageModelSession(
                instructions: "Output plain text only. Exactly 4 lines. No labels, no JSON, no markdown."
            )
            let response = try await session.respond(to: prompt)
            let raw = (response as? CustomStringConvertible)?.description ?? String(describing: response)

            // rawContent: "..." を取り出す
            if let range = raw.range(of: #"rawContent: \"(.*?)\""#, options: .regularExpression) {
                let seg = String(raw[range])
                let prefix = "rawContent: \""
                if seg.hasPrefix(prefix) && seg.hasSuffix("\"") {
                    return String(seg.dropFirst(prefix.count).dropLast())
                        .replacingOccurrences(of: "\\n", with: "\n")
                }
            }
            return raw.replacingOccurrences(of: "\\n", with: "\n")
        }
        #endif
        throw ConversationError.notAvailable
    }

    private func parseScene(raw: String, card: WordCard) throws -> ConversationScene {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count >= 4 else {
            throw ConversationError.parseError("4行取れませんでした(\(lines.count)行)")
        }

        return ConversationScene(
            card: card,
            partnerOpeningEnglish: lines[0],
            partnerOpeningJapanese: lines[1],
            partnerReplyEnglish: lines[2],
            partnerReplyJapanese: lines[3]
        )
    }
}

// MARK: - Errors

enum ConversationError: LocalizedError {
    case notAvailable
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Intelligence が利用できません（iOS 18.2以降の対応デバイスが必要です）"
        case .parseError(let msg):
            return "会話の生成に失敗しました: \(msg)"
        }
    }
}
