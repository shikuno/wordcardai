// ConversationViewModel.swift
// ロールプレイ会話練習の状態管理

import Foundation
import SwiftUI
import Combine

@MainActor
final class ConversationViewModel: ObservableObject {

    // MARK: - State

    enum Phase {
        case loading               // AI生成中
        case partnerSpeaking       // 相手のセリフ表示
        case showHint              // ヒント（日本語）表示・シンキングタイム
        case thinkingCountdown     // カウントダウン
        case showAnswer            // 正解英語を表示・読み上げ
        case nextReady             // 次へ進む準備完了
        case finished              // 全ターン終了
        case error(String)
    }

    @Published var phase: Phase = .loading
    @Published var session: ConversationSession?
    @Published var currentTurnIndex: Int = 0
    @Published var countdown: Int = 0
    @Published var thinkingSeconds: Int = 5   // シンキングタイム（設定可能）

    var currentTurn: ConversationTurn? {
        guard let session, currentTurnIndex < session.turns.count else { return nil }
        return session.turns[currentTurnIndex]
    }

    var progress: String {
        guard let session else { return "" }
        return "\(currentTurnIndex + 1) / \(session.turns.count)"
    }

    var isLastTurn: Bool {
        guard let session else { return true }
        return currentTurnIndex >= session.turns.count - 1
    }

    private let speechService = SpeechService.shared
    private var countdownTask: Task<Void, Never>?

    // MARK: - Public

    func start(cards: [WordCard], turnCount: Int) async {
        phase = .loading
        do {
            let svc = ConversationService.shared
            var sess = try await svc.generateSession(cards: cards, turnCount: turnCount)
            // collectionTitleを外から設定できないためミュータブルなコピーは不要 → そのまま使用
            session = sess
            currentTurnIndex = 0
            beginTurn()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// 正解英語を再生
    func speakAnswer() {
        guard let turn = currentTurn else { return }
        speechService.speak(turn.myEnglish, rate: 1.0)
    }

    /// 相手のセリフを音声で読み上げる
    func speakPartner() {
        guard let turn = currentTurn else { return }
        speechService.speak(turn.partnerEnglish, rate: 1.0)
    }

    /// ヒントを表示してシンキングタイムを開始
    func showHintAndCountdown() {
        phase = .showHint
        startCountdown()
    }

    /// 正解を表示して読み上げ
    func revealAnswer() {
        countdownTask?.cancel()
        guard let turn = currentTurn else { return }
        phase = .showAnswer
        speechService.speak(turn.myEnglish, rate: 1.0) { [weak self] in
            Task { @MainActor [weak self] in
                self?.phase = .nextReady
            }
        }
    }

    /// 次のターンへ
    func goNext() {
        guard let session else { return }
        if currentTurnIndex < session.turns.count - 1 {
            currentTurnIndex += 1
            beginTurn()
        } else {
            phase = .finished
        }
    }

    func stop() {
        countdownTask?.cancel()
        speechService.stop()
    }

    // MARK: - Private

    private func beginTurn() {
        phase = .partnerSpeaking
        speakPartner()
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
                if self.countdown <= 0 {
                    self.revealAnswer()
                }
            }
        }
    }
}
