//
//  TranslationServiceProtocol.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

protocol TranslationServiceProtocol {
    /// Step1: 入力テキストを1件だけ翻訳して返す
    /// Translation Framework 優先、なければ LLM にフォールバック
    func translateOnce(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String

    /// Step2: 翻訳済みテキストをもとに自然な表現を N 件生成する（LLM）
    func generateNaturalExpressions(from translated: String, targetLanguage: String, count: Int) async throws -> [String]
}

enum TranslationError: Error, LocalizedError {
    case emptyInput
    case networkError
    case processingError
    case unavailable

    var errorDescription: String? {
        switch self {
        case .emptyInput:       return "入力テキストが空です"
        case .networkError:     return "ネットワークエラーが発生しました"
        case .processingError:  return "翻訳処理中にエラーが発生しました"
        case .unavailable:      return "翻訳機能が利用できません"
        }
    }
}
