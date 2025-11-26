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
    @Published var japanese: String = ""
    @Published var english: String = ""
    @Published var note: String = ""
    @Published var tagsText: String = ""
    @Published var candidates: [String] = []
    @Published var selectedCandidateIndex: Int?
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    
    private let translationService: TranslationServiceProtocol
    private let candidateCount: Int
    
    var isValid: Bool {
        japanese.isNotEmpty && english.isNotEmpty
    }
    
    var tags: [String] {
        tagsText.splitTags()
    }
    
    init(translationService: TranslationServiceProtocol, candidateCount: Int) {
        self.translationService = translationService
        self.candidateCount = candidateCount
    }
    
    func loadCard(_ card: WordCard) {
        japanese = card.japanese
        english = card.english
        note = card.note ?? ""
        tagsText = card.tags.joined(separator: ", ")
        candidates = card.candidates
        
        if let index = candidates.firstIndex(of: card.english) {
            selectedCandidateIndex = index
        }
    }
    
    func generateCandidates() async {
        guard japanese.isNotEmpty else {
            errorMessage = "日本語を入力してください"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            candidates = try await translationService.generateCandidates(from: japanese, count: candidateCount)
            
            if !candidates.isEmpty {
                selectCandidate(at: 0)
            }
        } catch {
            errorMessage = "候補の生成に失敗しました: \(error.localizedDescription)"
            candidates = []
        }
        
        isGenerating = false
    }
    
    func selectCandidate(at index: Int) {
        guard index < candidates.count else { return }
        selectedCandidateIndex = index
        english = candidates[index]
    }
    
    func createCard(for collectionId: UUID) -> WordCard? {
        guard isValid else { return nil }
        
        return WordCard(
            collectionId: collectionId,
            japanese: japanese.trimmed,
            english: english.trimmed,
            candidates: candidates,
            note: note.isEmpty ? nil : note.trimmed,
            tags: tags
        )
    }
    
    func updateCard(_ card: WordCard) -> WordCard {
        var updatedCard = card
        updatedCard.japanese = japanese.trimmed
        updatedCard.english = english.trimmed
        updatedCard.candidates = candidates
        updatedCard.note = note.isEmpty ? nil : note.trimmed
        updatedCard.tags = tags
        return updatedCard
    }
    
    func reset() {
        japanese = ""
        english = ""
        note = ""
        tagsText = ""
        candidates = []
        selectedCandidateIndex = nil
        errorMessage = nil
    }
}
