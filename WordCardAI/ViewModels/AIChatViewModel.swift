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
                // Response<String>.content が本文
                let text = response.content

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

}

enum AIChatError: LocalizedError {
    case sessionError
    var errorDescription: String? { "セッションの作成に失敗しました" }
}
