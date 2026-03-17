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
    @Published var currentIndex: Int = 0
    @Published var isShowingBack: Bool = false
    @Published var isPlaying = false
    @Published var playbackRate: Double = 0.5
    @Published var speechTarget: PlaybackSpeechTarget = .frontOnly
    @Published var autoAdvanceDelay: Double = 0.8

    private let speechService: SpeechService

    let playbackPresets: [Double] = [0.4, 0.5, 0.6, 0.7]

    var playbackSpeedText: String {
        String(format: "%.1fx", playbackRate)
    }

    var autoAdvanceDelayText: String {
        if autoAdvanceDelay == 0 {
            return "0秒"
        }
        if autoAdvanceDelay.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(autoAdvanceDelay))秒"
        }
        return String(format: "%.1f秒", autoAdvanceDelay)
    }

    init(cards: [WordCard], speechService: SpeechService? = nil) {
        self.cards = cards
        self.speechService = speechService ?? SpeechService.shared
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
        case ..<0.48:
            return "ゆっくり"
        case ..<0.58:
            return "標準"
        case ..<0.65:
            return "やや速い"
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
                self.isShowingBack = true
                self.speechService.speak(card.english, rate: Float(self.playbackRate)) { [weak self] in
                    self?.advanceAfterPlayback()
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
    case frontOnly
    case frontAndBack
    case backOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frontOnly: return "表だけ"
        case .frontAndBack: return "表→裏"
        case .backOnly: return "裏だけ"
        }
    }
}
