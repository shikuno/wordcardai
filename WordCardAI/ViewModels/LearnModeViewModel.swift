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
    @Published var selectedCards: [WordCard] = []   // 会話練習に渡す用
    @Published var currentIndex: Int = 0
    @Published var isShowingAnswer: Bool = false
    @Published var questionCount: Int = 10
    @Published var order: LearnCardOrder = .random
    @Published var isConfigured: Bool = false
    @Published var sessionCompleted = false

    let questionCountOptions = [5, 10, 20, 30, 50]

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
        return "\(min(currentIndex + 1, cards.count)) / \(cards.count)"
    }

    var isFirstCard: Bool {
        currentIndex == 0
    }

    var isLastCard: Bool {
        currentIndex >= cards.count - 1
    }

    func availableQuestionCounts(for sourceCards: [WordCard]) -> [Int] {
        let maxCount = max(1, sourceCards.count)
        let options = Set(questionCountOptions + [maxCount])
        return options.filter { $0 <= maxCount }.sorted()
    }

    func prepare(with sourceCards: [WordCard]) {
        let counts = availableQuestionCounts(for: sourceCards)
        if counts.isEmpty == false,
           !counts.contains(questionCount) {
            questionCount = counts.last ?? 1
        }
        isConfigured = false
        sessionCompleted = false
    }

    func startSession(with sourceCards: [WordCard]) {
        var pool: [WordCard]
        switch order {
        case .random:      pool = sourceCards.shuffled()
        case .topToBottom: pool = sourceCards
        case .bottomToTop: pool = sourceCards.reversed()
        }
        pool = Array(pool.prefix(questionCount))

        selectedCards = pool   // 会話練習用に保持
        cards = pool
        currentIndex = 0
        isShowingAnswer = false
        sessionCompleted = false
        isConfigured = true
    }

    func toggleAnswer() {
        isShowingAnswer.toggle()
    }

    func nextCard() {
        guard currentIndex < cards.count - 1 else {
            sessionCompleted = true
            return
        }
        currentIndex += 1
        isShowingAnswer = false
    }

    func previousCard() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        isShowingAnswer = false
    }

    func resetSession(with sourceCards: [WordCard]) {
        startSession(with: sourceCards)
    }

    func applyEvaluation(_ evaluation: LearnCardEvaluation) -> WordCard? {
        guard var card = currentCard else { return nil }

        let now = Date()
        card.reviewCount += 1
        card.lastReviewedAt = now

        switch evaluation {
        case .again:
            card.learningStatus = .notSure
            card.nextReviewAt = Calendar.current.date(byAdding: .minute, value: 10, to: now)
        case .notSure:
            card.learningStatus = .reviewing
            card.correctCount += 1
            card.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: now)
        case .mastered:
            card.learningStatus = .mastered
            card.correctCount += 1
            card.nextReviewAt = nextSpacedReviewDate(reviewCount: card.reviewCount, from: now)
        }

        cards[currentIndex] = card
        nextCard()
        return card
    }

    func dueCardCount(in sourceCards: [WordCard]) -> Int {
        let now = Date()
        return sourceCards.filter {
            guard let nextReviewAt = $0.nextReviewAt else { return $0.learningStatus != .mastered }
            return nextReviewAt <= now
        }.count
    }

    private func selectSpacedRepetitionCards(from sourceCards: [WordCard]) -> [WordCard] {
        let now = Date()
        let dueCards = sourceCards.filter {
            guard let nextReviewAt = $0.nextReviewAt else { return $0.learningStatus != .mastered }
            return nextReviewAt <= now
        }
        .sorted {
            ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast)
        }

        if dueCards.count >= questionCount {
            return Array(dueCards.prefix(questionCount))
        }

        let remaining = sourceCards
            .filter { card in
                !dueCards.contains(where: { $0.id == card.id })
            }
            .sorted {
                rank(for: $0, now: now) < rank(for: $1, now: now)
            }

        return Array((dueCards + remaining).prefix(questionCount))
    }

    private func rank(for card: WordCard, now: Date) -> Int {
        if let nextReviewAt = card.nextReviewAt, nextReviewAt <= now { return 0 }
        switch card.learningStatus {
        case .new: return 1
        case .notSure: return 2
        case .reviewing: return 3
        case .mastered: return 4
        }
    }

    private func nextSpacedReviewDate(reviewCount: Int, from date: Date) -> Date {
        let days: Int
        switch reviewCount {
        case 0...1: days = 1
        case 2: days = 3
        case 3: days = 7
        case 4: days = 14
        default: days = 30
        }
        return Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}

enum LearnSessionMode: String, CaseIterable, Identifiable {
    case normal

    var id: String { rawValue }
    var title: String { "通常" }
    var description: String { "設定した順番で出題" }
}

enum LearnCardOrder: String, CaseIterable, Identifiable {
    case random
    case topToBottom
    case bottomToTop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .random: return "ランダム"
        case .topToBottom: return "上から順番"
        case .bottomToTop: return "下から順番"
        }
    }

    var icon: String {
        switch self {
        case .random: return "shuffle"
        case .topToBottom: return "arrow.down"
        case .bottomToTop: return "arrow.up"
        }
    }
}

enum LearnStartPosition: String, CaseIterable, Identifiable {
    case beginning
    case middle
    case notMastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginning: return "最初から"
        case .middle: return "途中から（中間）"
        case .notMastered: return "未習得を優先"
        }
    }

    var icon: String {
        switch self {
        case .beginning: return "1.circle"
        case .middle: return "arrow.right.to.line"
        case .notMastered: return "exclamationmark.circle"
        }
    }
}

enum LearnCardEvaluation: CaseIterable {
    case again
    case notSure
    case mastered

    var title: String {
        switch self {
        case .again:
            return "まだ無理"
        case .notSure:
            return "あやしい"
        case .mastered:
            return "覚えた"
        }
    }

    var color: Color {
        switch self {
        case .again:
            return .red
        case .notSure:
            return .orange
        case .mastered:
            return .green
        }
    }
}
