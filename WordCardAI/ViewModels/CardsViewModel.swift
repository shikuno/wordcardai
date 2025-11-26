//
//  CardsViewModel.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CardsViewModel: ObservableObject {
    @Published var cards: [WordCard] = []
    @Published var searchText: String = ""
    @Published var errorMessage: String?
    
    private let storage: StorageProtocol
    private var allCards: [WordCard] = []
    
    var filteredCards: [WordCard] {
        if searchText.isEmpty {
            return cards
        }
        return cards.filter { card in
            card.japanese.localizedCaseInsensitiveContains(searchText) ||
            card.english.localizedCaseInsensitiveContains(searchText) ||
            card.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    init(storage: StorageProtocol) {
        self.storage = storage
        loadAllCards()
    }
    
    func loadCards(for collectionId: UUID) {
        cards = allCards.filter { $0.collectionId == collectionId }
        cards.sort { $0.createdAt > $1.createdAt }
    }
    
    func loadAllCards() {
        do {
            allCards = try storage.loadCards()
        } catch {
            errorMessage = "カードの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func createCard(_ card: WordCard) {
        allCards.append(card)
        saveCards()
        loadCards(for: card.collectionId)
    }
    
    func updateCard(_ card: WordCard) {
        if let index = allCards.firstIndex(where: { $0.id == card.id }) {
            allCards[index] = card
            saveCards()
            loadCards(for: card.collectionId)
        }
    }
    
    func deleteCard(_ card: WordCard) {
        allCards.removeAll { $0.id == card.id }
        saveCards()
        loadCards(for: card.collectionId)
    }
    
    func deleteCards(for collectionId: UUID) {
        allCards.removeAll { $0.collectionId == collectionId }
        saveCards()
    }
    
    func cardCount(for collectionId: UUID) -> Int {
        allCards.filter { $0.collectionId == collectionId }.count
    }
    
    private func saveCards() {
        do {
            try storage.saveCards(allCards)
        } catch {
            errorMessage = "カードの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
