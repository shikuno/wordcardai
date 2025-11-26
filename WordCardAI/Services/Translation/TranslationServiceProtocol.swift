//
//  TranslationServiceProtocol.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

protocol TranslationServiceProtocol {
    func generateCandidates(from japanese: String, count: Int) async throws -> [String]
}

enum TranslationError: Error, LocalizedError {
    case emptyInput
    case networkError
    case processingError
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "入力テキストが空です"
        case .networkError:
            return "ネットワークエラーが発生しました"
        case .processingError:
            return "翻訳処理中にエラーが発生しました"
        }
    }
}
