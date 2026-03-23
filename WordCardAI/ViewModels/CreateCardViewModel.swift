//
//  CreateCardViewModel.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CreateCardViewModel: ObservableObject {
    // MARK: - 入力フィールド
    @Published var inputText: String = ""   // 翻訳元（言語問わず）
    @Published var english: String = ""
    @Published var note: String = ""
    @Published var tagsText: String = ""

    // MARK: - Step1 状態
    @Published var translatedText: String = ""      // Step1 の結果
    @Published var isTranslating: Bool = false

    // MARK: - Step2 状態
    @Published var naturalExpressions: [String] = []
    @Published var selectedExpressionIndex: Int?
    @Published var isGeneratingExpressions: Bool = false

    // MARK: - 共通
    @Published var errorMessage: String?
    @Published var rawAIOutput: String? = nil       // デバッグ用

    private let translationService: TranslationServiceProtocol
    private let naturalExpressionCount: Int

    var isValid: Bool {
        inputText.isNotEmpty && english.isNotEmpty
    }

    var tags: [String] {
        tagsText.splitTags()
    }

    /// Step2 ボタンを表示すべきかどうか（Step1 完了後かつ LLM 利用可能な場合）
    var canGenerateExpressions: Bool {
        !translatedText.isEmpty && !isTranslating
    }

    init(translationService: TranslationServiceProtocol, naturalExpressionCount: Int = 3) {
        self.translationService = translationService
        self.naturalExpressionCount = naturalExpressionCount
    }

    // MARK: - カード読み込み（編集時）

    func loadCard(_ card: WordCard) {
        inputText = card.japanese
        english = card.english
        note = card.note ?? ""
        tagsText = card.tags.joined(separator: ", ")
        naturalExpressions = card.candidates
        if let index = naturalExpressions.firstIndex(of: card.english) {
            selectedExpressionIndex = index
        }
    }

    // MARK: - Step 1: 翻訳（1件）

    func translateOnce() async {
        guard inputText.isNotEmpty else {
            errorMessage = "テキストを入力してください"
            return
        }
        isTranslating = true
        errorMessage = nil
        naturalExpressions = []
        selectedExpressionIndex = nil

        do {
            let result = try await translationService.translateOnce(text: inputText, targetLanguage: "en")
            translatedText = result
            // 翻訳結果を英語欄に自動セット
            english = result
        } catch {
            errorMessage = "翻訳に失敗しました: \(error.localizedDescription)"
        }
        isTranslating = false
    }

    // MARK: - Step 2: 自然な表現を N 件生成

    func generateNaturalExpressions() async {
        let base = translatedText.isEmpty ? english : translatedText
        guard !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "翻訳結果がありません"
            return
        }
        isGeneratingExpressions = true
        errorMessage = nil

        do {
            let results = try await translationService.generateNaturalExpressions(
                from: base,
                count: naturalExpressionCount
            )
            rawAIOutput = """
            【ベーステキスト】
            \(base)

            【AI生出力（無加工）】
            \(FoundationModelsTranslationService.lastRawOutput)
            """
            naturalExpressions = results
            if !results.isEmpty {
                selectExpression(at: 0)
            }
        } catch {
            errorMessage = "自然な表現の生成に失敗しました: \(error.localizedDescription)"
            naturalExpressions = []
        }
        isGeneratingExpressions = false
    }

    // MARK: - 表現を選択

    func selectExpression(at index: Int) {
        guard index < naturalExpressions.count else { return }
        selectedExpressionIndex = index
        english = naturalExpressions[index]
    }

    // MARK: - カード保存

    func createCard(for collectionId: UUID) -> WordCard? {
        guard isValid else { return nil }
        return WordCard(
            collectionId: collectionId,
            japanese: inputText.trimmed,
            english: english.trimmed,
            candidates: naturalExpressions,
            note: note.isEmpty ? nil : note.trimmed,
            tags: tags
        )
    }

    func updateCard(_ card: WordCard) -> WordCard {
        var updated = card
        updated.japanese = inputText.trimmed
        updated.english = english.trimmed
        updated.candidates = naturalExpressions
        updated.note = note.isEmpty ? nil : note.trimmed
        updated.tags = tags
        return updated
    }

    func reset() {
        inputText = ""
        english = ""
        note = ""
        tagsText = ""
        translatedText = ""
        naturalExpressions = []
        selectedExpressionIndex = nil
        errorMessage = nil
    }
}
