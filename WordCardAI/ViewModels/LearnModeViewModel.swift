//
//  LearnModeViewModel.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class LearnModeViewModel: ObservableObject {
    @Published var cards: [WordCard] = []
    @Published var currentIndex: Int = 0
    @Published var isShowingAnswer: Bool = false
    
    var currentCard: WordCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }
    
    var progress: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(cards.count)
    }
    
    var progressText: String {
        guard !cards.isEmpty else { return "0 / 0" }
        return "\(currentIndex + 1) / \(cards.count)"
    }
    
    var isFirstCard: Bool {
        currentIndex == 0
    }
    
    var isLastCard: Bool {
        currentIndex == cards.count - 1
    }
    
    func loadCards(_ cards: [WordCard]) {
        self.cards = cards.shuffled()
        currentIndex = 0
        isShowingAnswer = false
    }
    
    func toggleAnswer() {
        isShowingAnswer.toggle()
    }
    
    func nextCard() {
        guard currentIndex < cards.count - 1 else { return }
        currentIndex += 1
        isShowingAnswer = false
    }
    
    func previousCard() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        isShowingAnswer = false
    }
    
    func reset() {
        currentIndex = 0
        isShowingAnswer = false
        cards = cards.shuffled()
    }
}
