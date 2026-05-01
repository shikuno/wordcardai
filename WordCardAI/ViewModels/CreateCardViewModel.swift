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
    @Published var isTranslating: Bool = false

    // MARK: - Step2 状態（表面→裏面）
    @Published var naturalExpressions: [String] = []
    @Published var selectedExpressionIndex: Int?
    @Published var isGeneratingExpressions: Bool = false

    // MARK: - Step2 状態（裏面→表面）
    @Published var naturalExpressionsReverse: [String] = []
    @Published var selectedExpressionReverseIndex: Int?
    @Published var isGeneratingExpressionsReverse: Bool = false

    // MARK: - 候補選択シート
    @Published var showCandidatePicker: Bool = false
    @Published var pickerCandidates: [String] = []
    @Published var pickerTargetIsFront: Bool = false   // true = 表面に入れる、false = 裏面に入れる
    @Published var pickerTitle: String = ""

    // MARK: - 共通
    @Published var errorMessage: String?
    @Published var rawAIOutput: String? = nil

    private let translationService: TranslationServiceProtocol
    private let naturalExpressionCount: Int

    private func buildDebugInfo(
        procedure: [String],
        sourceText: String? = nil,
        intermediateText: String? = nil
    ) -> String {
        let steps = procedure.enumerated().map { index, step in
            "\(index + 1). \(step)"
        }.joined(separator: "\n")

        var sections: [String] = [
            "【生成手順】\n\(steps)"
        ]

        if let sourceText, !sourceText.isEmpty {
            sections.append("【元テキスト】\n\(sourceText)")
        }
        if let intermediateText, !intermediateText.isEmpty {
            sections.append("【中間翻訳】\n\(intermediateText)")
        }

        sections.append("【実行ログ（どの経路を通ったか）】\n\(FoundationModelsTranslationService.lastFlowLog)")
        sections.append("【プロンプト】\n\(FoundationModelsTranslationService.lastPrompt)")
        sections.append("【AI生出力（無加工）】\n\(FoundationModelsTranslationService.lastRawOutput)")

        return sections.joined(separator: "\n\n")
    }

    private func buildErrorDebugInfo(
        stage: String,
        procedure: [String],
        sourceText: String? = nil,
        intermediateText: String? = nil,
        error: Error? = nil
    ) -> String {
        var debugInfo = buildDebugInfo(
            procedure: procedure,
            sourceText: sourceText,
            intermediateText: intermediateText
        )

        debugInfo += "\n\n【失敗箇所】\n\(stage)"
        if let error {
            debugInfo += "\n\n【エラー詳細】\n\(error.localizedDescription)"
        }
        return debugInfo
    }

    var isValid: Bool {
        front.isNotEmpty && back.isNotEmpty
    }

    var tags: [String] {
        tagsText.splitTags()
    }

    var canGenerateExpressions: Bool {
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }

    var canGenerateExpressionsReverse: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
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
        naturalExpressions = []
        selectedExpressionIndex = nil
        naturalExpressionsReverse = []
        selectedExpressionReverseIndex = nil
        errorMessage = nil
    }

    // MARK: - Step 1: 翻訳（1件）→ 候補シートを開く

    func translateOnce() async {
        let src = sourceText
        guard !src.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "\(sourceLabel)のテキストを入力してください"
            rawAIOutput = buildErrorDebugInfo(
                stage: "翻訳開始前: 入力チェック",
                procedure: [
                    "\(sourceLabel)テキストを入力として受け取る",
                    "翻訳エンジンで \(sourceLanguage) → \(targetLanguage) の翻訳を実行",
                    "翻訳結果を候補として表示する"
                ],
                sourceText: src
            )
            return
        }
        isTranslating = true
        errorMessage = nil

        do {
            let result = try await translationService.translateOnce(
                text: src,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            rawAIOutput = buildDebugInfo(
                procedure: [
                    "\(sourceLabel)テキストを入力として受け取る",
                    "翻訳エンジンで \(sourceLanguage) → \(targetLanguage) の翻訳を実行",
                    "翻訳結果を候補として表示する"
                ],
                sourceText: src
            )
            // 直接セットせずシートで選ばせる
            pickerCandidates = [result]
            pickerTargetIsFront = !translateFrontToBack
            pickerTitle = "\(sourceLabel)の翻訳結果"
            showCandidatePicker = true
        } catch {
            rawAIOutput = buildErrorDebugInfo(
                stage: "翻訳実行",
                procedure: [
                    "\(sourceLabel)テキストを入力として受け取る",
                    "翻訳エンジンで \(sourceLanguage) → \(targetLanguage) の翻訳を実行",
                    "翻訳結果を候補として表示する"
                ],
                sourceText: src,
                error: error
            )
            errorMessage = "翻訳に失敗しました: \(error.localizedDescription)"
        }
        isTranslating = false
    }

    // MARK: - Step 2: 自然な表現を N 件生成（表面→裏面）→ 候補シートを開く

    func generateNaturalExpressions() async {
        let base = front.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            errorMessage = "表面のテキストを入力してください"
            rawAIOutput = buildErrorDebugInfo(
                stage: "自然な表現生成開始前: 入力チェック",
                procedure: [
                    "表面テキストを受け取る",
                    "表面言語 \(frontLanguage) から裏面言語 \(backLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base
            )
            return
        }
        isGeneratingExpressions = true
        errorMessage = nil

        do {
            let results = try await translationService.generateNaturalExpressionsDirect(
                from: base,
                sourceLanguage: frontLanguage,
                targetLanguage: backLanguage,
                count: naturalExpressionCount
            )
            rawAIOutput = buildDebugInfo(
                procedure: [
                    "表面テキストを受け取る",
                    "表面言語 \(frontLanguage) から裏面言語 \(backLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base
            )
            naturalExpressions = results
            pickerCandidates = results
            pickerTargetIsFront = false
            pickerTitle = "AIが生成した自然な表現（裏面用）"
            showCandidatePicker = true
        } catch {
            rawAIOutput = buildErrorDebugInfo(
                stage: "自然な表現生成（表面→裏面）",
                procedure: [
                    "表面テキストを受け取る",
                    "表面言語 \(frontLanguage) から裏面言語 \(backLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base,
                error: error
            )
            errorMessage = "自然な表現の生成に失敗しました: \(error.localizedDescription)"
            naturalExpressions = []
        }
        isGeneratingExpressions = false
    }

    // MARK: - Step 2: 自然な表現を N 件生成（裏面→表面）→ 候補シートを開く

    func generateNaturalExpressionsReverse() async {
        let base = back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            errorMessage = "裏面のテキストを入力してください"
            rawAIOutput = buildErrorDebugInfo(
                stage: "自然な表現生成開始前: 入力チェック",
                procedure: [
                    "裏面テキストを受け取る",
                    "裏面言語 \(backLanguage) から表面言語 \(frontLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base
            )
            return
        }
        isGeneratingExpressionsReverse = true
        errorMessage = nil

        do {
            let results = try await translationService.generateNaturalExpressionsDirect(
                from: base,
                sourceLanguage: backLanguage,
                targetLanguage: frontLanguage,
                count: naturalExpressionCount
            )
            naturalExpressionsReverse = results
            rawAIOutput = buildDebugInfo(
                procedure: [
                    "裏面テキストを受け取る",
                    "裏面言語 \(backLanguage) から表面言語 \(frontLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base
            )
            pickerCandidates = results
            pickerTargetIsFront = true
            pickerTitle = "AIが生成した自然な表現（表面用）"
            showCandidatePicker = true
        } catch {
            rawAIOutput = buildErrorDebugInfo(
                stage: "自然な表現生成（裏面→表面）",
                procedure: [
                    "裏面テキストを受け取る",
                    "裏面言語 \(backLanguage) から表面言語 \(frontLanguage) へ、自然な表現を直接 \(naturalExpressionCount) 件生成する",
                    "生成候補を一覧表示する"
                ],
                sourceText: base,
                error: error
            )
            errorMessage = "自然な表現の生成に失敗しました: \(error.localizedDescription)"
            naturalExpressionsReverse = []
        }
        isGeneratingExpressionsReverse = false
    }

    // MARK: - 候補を選択して入力欄にセット

    func applyCandidate(_ text: String) {
        if pickerTargetIsFront {
            front = text
        } else {
            back = text
        }
        showCandidatePicker = false
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
        selectedExpressionIndex = nil
        naturalExpressionsReverse = []
        selectedExpressionReverseIndex = nil
        pickerCandidates = []
        showCandidatePicker = false
        errorMessage = nil
        translateFrontToBack = true
    }
}
