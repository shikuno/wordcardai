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
    @Published var front: String = ""   // 表面テキスト
    @Published var back: String = ""    // 裏面テキスト
    @Published var note: String = ""
    @Published var tagsText: String = ""

    // MARK: - 翻訳方向（true = 表面→裏面、false = 裏面→表面）
    @Published var translateFrontToBack: Bool = true

    // MARK: - 言語設定（SettingsService から引き継ぐ）
    var frontLanguage: String = "ja"
    var backLanguage: String = "en"

    /// 翻訳元の言語コード
    var sourceLanguage: String { translateFrontToBack ? frontLanguage : backLanguage }
    /// 翻訳先の言語コード
    var targetLanguage: String { translateFrontToBack ? backLanguage : frontLanguage }
    /// 翻訳元テキスト
    var sourceText: String { translateFrontToBack ? front : back }
    /// 翻訳先ラベル
    var targetLabel: String { translateFrontToBack ? "裏面" : "表面" }
    /// 翻訳元ラベル
    var sourceLabel: String { translateFrontToBack ? "表面" : "裏面" }

    // MARK: - Step1 状態
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false

    // MARK: - Step2 状態
    @Published var naturalExpressions: [String] = []
    @Published var selectedExpressionIndex: Int?
    @Published var isGeneratingExpressions: Bool = false

    // MARK: - 共通
    @Published var errorMessage: String?
    @Published var rawAIOutput: String? = nil

    private let translationService: TranslationServiceProtocol
    private let naturalExpressionCount: Int

    var isValid: Bool {
        front.isNotEmpty && back.isNotEmpty
    }

    var tags: [String] {
        tagsText.splitTags()
    }

    var canGenerateExpressions: Bool {
        !translatedText.isEmpty && !isTranslating
    }

    init(translationService: TranslationServiceProtocol,
         naturalExpressionCount: Int = 3,
         frontLanguage: String = "ja",
         backLanguage: String = "en") {
        self.translationService = translationService
        self.naturalExpressionCount = naturalExpressionCount
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
    }

    // MARK: - カード読み込み（編集時）

    func loadCard(_ card: WordCard) {
        front = card.front
        back = card.back
        note = card.note ?? ""
        tagsText = card.tags.joined(separator: ", ")
        naturalExpressions = card.candidates
        if let index = naturalExpressions.firstIndex(of: card.back) {
            selectedExpressionIndex = index
        }
    }

    // MARK: - 翻訳方向トグル

    func toggleDirection() {
        translateFrontToBack.toggle()
        // 方向を変えたら翻訳結果・候補をリセット
        translatedText = ""
        naturalExpressions = []
        selectedExpressionIndex = nil
        errorMessage = nil
    }

    // MARK: - Step 1: 翻訳（1件）

    func translateOnce() async {
        let src = sourceText
        guard !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "\(sourceLabel)のテキストを入力してください"
            return
        }
        isTranslating = true
        errorMessage = nil
        naturalExpressions = []
        selectedExpressionIndex = nil

        do {
            let result = try await translationService.translateOnce(
                text: src,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            translatedText = result
            // 翻訳先フィールドに自動セット
            if translateFrontToBack {
                back = result
            } else {
                front = result
            }
        } catch {
            errorMessage = "翻訳に失敗しました: \(error.localizedDescription)"
        }
        isTranslating = false
    }

    // MARK: - Step 2: 自然な表現を N 件生成

    func generateNaturalExpressions() async {
        let base = translatedText.isEmpty ? (translateFrontToBack ? back : front) : translatedText
        guard !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "翻訳結果がありません"
            return
        }
        isGeneratingExpressions = true
        errorMessage = nil

        do {
            let results = try await translationService.generateNaturalExpressions(
                from: base,
                targetLanguage: targetLanguage,
                count: naturalExpressionCount
            )
            rawAIOutput = """
            【ベーステキスト】
            \(base)

            【AI生出力（無加工）】
            \(FoundationModelsTranslationService.lastRawOutput)
            """
            naturalExpressions = results
            if !results.isEmpty { selectExpression(at: 0) }
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
        if translateFrontToBack {
            back = naturalExpressions[index]
        } else {
            front = naturalExpressions[index]
        }
    }

    // MARK: - カード保存

    func createCard(for collectionId: UUID) -> WordCard? {
        guard isValid else { return nil }
        return WordCard(
            collectionId: collectionId,
            front: front.trimmed,
            back: back.trimmed,
            candidates: naturalExpressions,
            note: note.isEmpty ? nil : note.trimmed,
            tags: tags
        )
    }

    func updateCard(_ card: WordCard) -> WordCard {
        var updated = card
        updated.front = front.trimmed
        updated.back = back.trimmed
        updated.candidates = naturalExpressions
        updated.note = note.isEmpty ? nil : note.trimmed
        updated.tags = tags
        return updated
    }

    func reset() {
        front = ""
        back = ""
        note = ""
        tagsText = ""
        translatedText = ""
        naturalExpressions = []
        selectedExpressionIndex = nil
        errorMessage = nil
        translateFrontToBack = true
    }
}
