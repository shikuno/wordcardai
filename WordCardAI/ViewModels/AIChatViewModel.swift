// AIChatViewModel.swift
import Foundation
import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // FoundationModels のセッションを保持（会話履歴を引き継ぐ）
    private var session: Any? = nil

    private let systemInstructions = """
    あなたは英語学習のサポートAIです。
    ユーザーの英語学習に関する質問・相談に日本語で答えてください。
    - フレーズの使い方、ニュアンスの違い、自然な表現の提案など何でもOKです
    - 例文は英語で示し、その日本語訳も添えてください
    - 丁寧でわかりやすい説明を心がけてください
    - マークダウン記号（*, **, #, ~~, _ など）は絶対に使わないでください
    - プレーンテキストのみで回答してください
    """

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text))
        isLoading = true
        errorMessage = nil

        Task { await callAI(userMessage: text) }
    }

    func clear() {
        messages = []
        session = nil
        errorMessage = nil
    }

    // MARK: - Private

    private func callAI(userMessage: String) async {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            do {
                // セッションが未作成なら作る（会話履歴を維持するため同一セッションを再利用）
                if session == nil {
                    session = LanguageModelSession(instructions: systemInstructions)
                }
                guard let lmSession = session as? LanguageModelSession else {
                    throw AIChatError.sessionError
                }
                let response = try await lmSession.respond(to: userMessage)

                // respond(to:) の戻り値を文字列として取り出す
                // iOS 26+ では GeneratedContent 型で、description に本文が入っている
                let raw: String
                if let str = response as? String {
                    raw = str
                } else {
                    raw = String(describing: response)
                }

                // マークダウン記号を除去してクリーンなテキストにする
                let text = cleanMarkdown(raw)

                messages.append(ChatMessage(role: .assistant, text: text))
                isLoading = false
                return
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }
        }
        #endif
        isLoading = false
        errorMessage = "Apple Intelligence が利用できません（iOS 18.2以降の対応デバイスが必要です）"
    }

    /// マークダウン記号を除去してプレーンテキストにする
    private func cleanMarkdown(_ input: String) -> String {
        var text = input

        // \n リテラル文字列を実際の改行に変換
        text = text.replacingOccurrences(of: "\\n", with: "\n")

        // **太字** → 太字
        text = text.replacingOccurrences(of: "**", with: "")
        // *斜体* → 斜体（ただし I'm などのアポストロフィは保持）
        // 行頭の * だけ除去（箇条書き）
        let lines = text.components(separatedBy: .newlines).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            // 行頭の "* " や "- " を除去
            if l.hasPrefix("* ") { l = String(l.dropFirst(2)) }
            else if l.hasPrefix("- ") { l = String(l.dropFirst(2)) }
            else if l.hasPrefix("• ") { l = String(l.dropFirst(2)) }
            // 行頭の "# " "## " 等を除去
            while l.hasPrefix("#") { l = String(l.dropFirst()) }
            l = l.trimmingCharacters(in: .whitespaces)
            return l
        }
        text = lines.joined(separator: "\n")

        // ~~打ち消し~~ を除去
        text = text.replacingOccurrences(of: "~~", with: "")
        // `コード` を除去
        text = text.replacingOccurrences(of: "`", with: "")
        // __太字__ を除去
        text = text.replacingOccurrences(of: "__", with: "")

        // 連続する空行を1つにまとめる
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIChatError: LocalizedError {
    case sessionError
    var errorDescription: String? { "セッションの作成に失敗しました" }
}
