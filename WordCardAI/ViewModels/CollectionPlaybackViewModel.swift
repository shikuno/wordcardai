//
//  CollectionPlaybackViewModel.swift
//  WordCardAI
//
//  Created by Copilot on 2026/03/17.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CollectionPlaybackViewModel: ObservableObject {
    @Published private(set) var cards: [WordCard]
    private(set) var allCards: [WordCard] = []   // フィルター前の全カード
    @Published var currentIndex: Int = 0 {
        didSet { persistIndex() }
    }
    @Published var isShowingBack: Bool = false
    @Published var isPlaying = false
    @Published var playbackRate: Double = 1.0
    @Published var speechTarget: PlaybackSpeechTarget = .frontOnly
    @Published var autoAdvanceDelay: Double = 2.0
    @Published var frontToBackDelay: Double = 1.0

    private let speechService: SpeechService
    private let collectionId: String

    let playbackPresets: [Double] = [0.25, 0.5, 1.0, 1.5, 2.0]

    var playbackSpeedText: String {
        String(format: "%.2gx", playbackRate)
    }

    var autoAdvanceDelayText: String {
        if autoAdvanceDelay == 0 { return "0秒" }
        if autoAdvanceDelay.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(autoAdvanceDelay))秒"
        }
        return String(format: "%.1f秒", autoAdvanceDelay)
    }

    init(cards: [WordCard], collectionId: String = "", speechService: SpeechService? = nil) {
        self.cards = cards
        self.allCards = cards
        self.collectionId = collectionId
        self.speechService = speechService ?? SpeechService.shared
        // 保存済みのインデックスを復元
        if !collectionId.isEmpty && !cards.isEmpty {
            let saved = UserDefaults.standard.integer(forKey: "cardIndex_\(collectionId)")
            self.currentIndex = max(0, min(saved, cards.count - 1))
        }
    }

    private func persistIndex() {
        guard !collectionId.isEmpty else { return }
        UserDefaults.standard.set(currentIndex, forKey: "cardIndex_\(collectionId)")
    }

    var currentCard: WordCard? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var progressText: String {
        guard !cards.isEmpty else { return "0 / 0" }
        return "\(currentIndex + 1) / \(cards.count)"
    }

    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < cards.count - 1 }

    var playbackSpeedLabel: String {
        switch playbackRate {
        case ..<0.4:
            return "かなりゆっくり"
        case ..<0.75:
            return "ゆっくり"
        case ..<1.25:
            return "標準"
        case ..<1.75:
            return "速い"
        default:
            return "かなり速い"
        }
    }

    func goNext() {
        guard canGoNext else { return }
        stopPlayback()
        currentIndex += 1
        isShowingBack = false
    }

    func goPrevious() {
        guard canGoPrevious else { return }
        stopPlayback()
        currentIndex -= 1
        isShowingBack = false
    }

    func toggleSide() {
        isShowingBack.toggle()
    }

    func handleSwipe(translation: CGFloat) {
        let threshold: CGFloat = 70
        if translation < -threshold {
            goNext()
        } else if translation > threshold {
            goPrevious()
        }
    }

    func jumpTo(index: Int) {
        guard index >= 0, index < cards.count, index != currentIndex else { return }
        stopPlayback()
        currentIndex = index
        isShowingBack = false
    }

    func stopPlayback() {
        isPlaying = false
        speechService.stop()
    }

    func startPlayback() {
        guard currentCard != nil else { return }
        isPlaying = true
        isShowingBack = false
        playCurrentCard()
    }

    func restartFromCurrent() {
        stopPlayback()
        startPlayback()
    }

    func updateCards(_ newCards: [WordCard]) {
        allCards = newCards
        cards = newCards
        if cards.isEmpty {
            currentIndex = 0
            isShowingBack = false
            isPlaying = false
            return
        }
        currentIndex = min(currentIndex, cards.count - 1)
        isShowingBack = false
    }

    /// ステータスフィルターを適用してcardsを絞り込む
    func applyFilter(statuses: Set<LearningStatus>) {
        let current = currentCard
        if statuses.isSuperset(of: LearningStatus.allCases) {
            cards = allCards
        } else {
            cards = allCards.filter { statuses.contains($0.learningStatus) }
        }
        if cards.isEmpty { cards = allCards }  // 全消えを防ぐ
        // 現在のカードに近い位置に移動
        if let current = current, let idx = cards.firstIndex(where: { $0.id == current.id }) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
        isShowingBack = false
    }

    private func playCurrentCard() {
        guard isPlaying, let card = currentCard else { return }

        switch speechTarget {
        case .frontOnly:
            speechService.speak(card.japanese, rate: Float(playbackRate)) { [weak self] in
                self?.advanceAfterPlayback()
            }
        case .backOnly:
            self.isShowingBack = true
            speechService.speak(card.english, rate: Float(playbackRate)) { [weak self] in
                self?.advanceAfterPlayback()
            }
        case .frontAndBack:
            self.isShowingBack = false
            speechService.speak(card.japanese, rate: Float(playbackRate)) { [weak self] in
                guard let self, self.isPlaying else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.frontToBackDelay > 0 {
                        try? await Task.sleep(for: .seconds(self.frontToBackDelay))
                    }
                    guard self.isPlaying else { return }
                    self.isShowingBack = true
                    self.speechService.speak(card.english, rate: Float(self.playbackRate)) { [weak self] in
                        self?.advanceAfterPlayback()
                    }
                }
            }
        }
    }

    private func advanceAfterPlayback() {
        guard isPlaying else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoAdvanceDelay))
            guard isPlaying else { return }
            if canGoNext {
                currentIndex += 1
                isShowingBack = false
                playCurrentCard()
            } else {
                stopPlayback()
            }
        }
    }
}

enum PlaybackSpeechTarget: String, CaseIterable, Identifiable {
    case frontAndBack
    case frontOnly
    case backOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontAndBack: return "表裏"
        case .frontOnly: return "表だけ"
        case .backOnly: return "裏だけ"
        }
    }
}
