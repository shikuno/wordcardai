// ConversationViewModel.swift
// 1問ずつ会話シーンを生成・進行する

import Foundation
import SwiftUI
import Combine

@MainActor
final class ConversationViewModel: ObservableObject {

    enum Phase {
        case idle                  // 未開始
        case generating            // AIがこの問題を生成中
        case showOpening           // 相手の最初のセリフ表示
        case showHint              // ヒント（日本語）表示 + シンキング
        case countdown             // カウントダウン中
        case showAnswer            // 正解英語を表示・読み上げ中
        case showReply             // 相手の続きを表示
        case nextReady             // 次へ進める状態
        case finished              // 全問終了
        case error(String)
    }

    @Published var phase: Phase = .idle
    @Published var currentIndex: Int = 0
    @Published var currentScene: ConversationScene?
    @Published var countdown: Int = 0
    @Published var thinkingSeconds: Int = 5

    private(set) var cards: [WordCard] = []

    var progress: String {
        "\(currentIndex + 1) / \(cards.count)"
    }
    var isLastCard: Bool { currentIndex >= cards.count - 1 }

    private let speechService = SpeechService.shared
    private var countdownTask: Task<Void, Never>?

    // MARK: - Public

    /// カードのリストをセットして最初の問題を生成開始
    func start(cards: [WordCard], turnCount: Int) async {
        self.cards = Array(cards.prefix(turnCount))
        currentIndex = 0
        await generateCurrentScene()
    }

    func speakPartner() {
        guard let scene = currentScene else { return }
        speechService.speak(scene.partnerOpeningEnglish, rate: 1.0)
    }

    func speakAnswer() {
        guard let scene = currentScene else { return }
        speechService.speak(scene.card.english, rate: 1.0)
    }

    func speakReply() {
        guard let scene = currentScene else { return }
        speechService.speak(scene.partnerReplyEnglish, rate: 1.0)
    }

    func showHintAndCountdown() {
        phase = .showHint
        startCountdown()
    }

    func revealAnswer() {
        countdownTask?.cancel()
        guard let scene = currentScene else { return }
        phase = .showAnswer
        speechService.speak(scene.card.english, rate: 1.0) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.phase = .showReply
                // 相手の続きを読み上げ
                self.speechService.speak(scene.partnerReplyEnglish, rate: 1.0) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.phase = .nextReady
                    }
                }
            }
        }
    }

    func goNext() {
        if isLastCard {
            phase = .finished
        } else {
            currentIndex += 1
            Task { await generateCurrentScene() }
        }
    }

    func stop() {
        countdownTask?.cancel()
        speechService.stop()
    }

    // MARK: - Private

    private func generateCurrentScene() async {
        guard currentIndex < cards.count else { phase = .finished; return }
        phase = .generating
        let card = cards[currentIndex]
        do {
            let scene = try await ConversationService.shared.generateScene(for: card)
            currentScene = scene
            phase = .showOpening
            speakPartner()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    private func startCountdown() {
        countdown = thinkingSeconds
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while self.countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.countdown -= 1
                if self.countdown <= 0 { self.revealAnswer() }
            }
        }
    }
}
