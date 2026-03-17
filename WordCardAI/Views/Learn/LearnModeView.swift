//
//  LearnModeView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

extension Color {
    static var systemSecondaryBackgroundCompat: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color.secondary.opacity(0.1)
        #endif
    }
    static var systemTertiaryBackgroundCompat: Color {
        #if os(iOS)
        return Color(uiColor: .tertiarySystemBackground)
        #else
        return Color.secondary.opacity(0.05)
        #endif
    }
}

// MARK: - 学習モードのステップ管理

enum LearnStep {
    case modeSelect          // ① モード選択
    case settings            // ② 設定（問題数・順番）
    case flashcard           // ③ フラッシュカード本番
    case conversation        // ③ 会話練習本番
}

struct LearnModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LearnModeViewModel()
    @StateObject private var convVM = ConversationViewModel()
    private let speechService = SpeechService.shared

    let cards: [WordCard]
    let onUpdateCard: ((WordCard) -> Void)?

    @State private var step: LearnStep = .modeSelect
    @State private var selectedMode: LearnPracticeMode = .flashcard

    init(cards: [WordCard], onUpdateCard: ((WordCard) -> Void)? = nil) {
        self.cards = cards
        self.onUpdateCard = onUpdateCard
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyStateView
                } else {
                    switch step {
                    case .modeSelect:
                        modeSelectView
                    case .settings:
                        settingsView
                    case .flashcard:
                        flashcardSessionView
                    case .conversation:
                        conversationSessionView
                    }
                }
            }
            .padding(step == .conversation ? 0 : 16)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if step == .modeSelect {
                            speechService.stop()
                            convVM.stop()
                            dismiss()
                        } else {
                            withAnimation { goBack() }
                        }
                    } label: {
                        if step == .modeSelect {
                            Image(systemName: "xmark")
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("戻る")
                            }
                        }
                    }
                }
            }
            .onAppear { viewModel.prepare(with: cards) }
            .onDisappear {
                speechService.stop()
                convVM.stop()
            }
        }
    }

    private var navTitle: String {
        switch step {
        case .modeSelect: return "学習"
        case .settings: return selectedMode == .flashcard ? "フラッシュカード" : "会話練習"
        case .flashcard: return "フラッシュカード"
        case .conversation: return "会話練習"
        }
    }

    private func goBack() {
        switch step {
        case .settings: step = .modeSelect
        case .flashcard, .conversation: step = .settings
        default: break
        }
    }

    // MARK: - ① モード選択

    private var modeSelectView: some View {
        VStack(spacing: 20) {
            Text("どのモードで練習しますか？")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            modeCard(
                title: "フラッシュカード",
                description: "カードを見て自己評価\n覚えた・あやしい・まだ無理",
                icon: "rectangle.on.rectangle",
                color: .blue
            ) {
                selectedMode = .flashcard
                withAnimation { step = .settings }
            }

            modeCard(
                title: "会話練習",
                description: "相手のセリフに英語で返す\nAIがシチュエーションを生成",
                icon: "bubble.left.and.bubble.right.fill",
                color: .green
            ) {
                selectedMode = .conversation
                withAnimation { step = .settings }
            }

            Spacer()

            Text("全 \(cards.count) 枚のカード")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func modeCard(title: String, description: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.systemSecondaryBackgroundCompat)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - ② 設定

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 問題数
            VStack(alignment: .leading, spacing: 12) {
                Text("問題数")
                    .font(.headline)
                let counts = viewModel.availableQuestionCounts(for: cards)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 8) {
                    ForEach(counts, id: \.self) { count in
                        let selected = viewModel.questionCount == count
                        Button {
                            viewModel.questionCount = count
                        } label: {
                            Text("\(count)問")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selected ? Color.blue : Color.systemSecondaryBackgroundCompat)
                                .foregroundColor(selected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 順番
            VStack(alignment: .leading, spacing: 10) {
                Text("順番")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(LearnCardOrder.allCases) { ord in
                        let selected = viewModel.order == ord
                        Button {
                            viewModel.order = ord
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: ord.icon)
                                Text(ord.title)
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? Color.blue : Color.systemSecondaryBackgroundCompat)
                            .foregroundColor(selected ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // スタートボタン
            Button {
                viewModel.startSession(with: cards)
                if selectedMode == .flashcard {
                    withAnimation { step = .flashcard }
                } else {
                    withAnimation { step = .conversation }
                    Task {
                        await convVM.start(
                            cards: viewModel.selectedCards.isEmpty ? cards : viewModel.selectedCards,
                            turnCount: viewModel.questionCount
                        )
                    }
                }
            } label: {
                Text("\(viewModel.questionCount)問スタート")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedMode == .flashcard ? Color.blue : Color.green)
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - ③ フラッシュカード本番

    private var flashcardSessionView: some View {
        Group {
            if let card = viewModel.currentCard, !viewModel.sessionCompleted {
                learningContent(for: card)
            } else {
                completionView
            }
        }
    }

    // 会話練習はsheetで出すのでプレースホルダー
    private var conversationPlaceholder: some View {
        Color.clear.onAppear { step = .conversation }
    }

    // MARK: - ③ 会話練習本番（インライン）

    private var conversationSessionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                switch convVM.phase {
                case .loading:
                    convLoadingView

                case .error(let msg):
                    convErrorView(msg)

                case .finished:
                    convFinishedView

                default:
                    if let turn = convVM.currentTurn {
                        // 進捗
                        VStack(spacing: 6) {
                            Text("ターン \(convVM.progress)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            ProgressView(value: Double(convVM.currentTurnIndex + 1),
                                         total: Double(convVM.session?.turns.count ?? 1))
                                .tint(.green)
                        }
                        .padding(.horizontal)

                        // 相手のセリフ
                        convPartnerCard(turn: turn)

                        // 自分の返答エリア
                        convMyCard(turn: turn)

                        // 次へボタン
                        if case .nextReady = convVM.phase {
                            Button {
                                convVM.goNext()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(convVM.isLastTurn ? "完了" : "次のターンへ")
                                        .fontWeight(.semibold)
                                    Image(systemName: convVM.isLastTurn ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var convLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.3)
            Text("AIが会話を生成中…")
                .font(.headline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private func convErrorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundColor(.orange)
            Text("会話を生成できませんでした").font(.headline)
            Text(msg).font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("もう一度試す") {
                Task {
                    await convVM.start(
                        cards: viewModel.selectedCards.isEmpty ? cards : viewModel.selectedCards,
                        turnCount: viewModel.questionCount
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var convFinishedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 56)).foregroundColor(.yellow)
            Text("練習完了！").font(.largeTitle.bold())
            Text("\(convVM.session?.turns.count ?? 0)つのフレーズを使いました")
                .font(.subheadline).foregroundColor(.secondary)
            Button("もう一度（別の会話）") {
                Task {
                    await convVM.start(
                        cards: viewModel.selectedCards.isEmpty ? cards : viewModel.selectedCards,
                        turnCount: viewModel.questionCount
                    )
                }
            }
            .buttonStyle(.borderedProminent).tint(.green)
            Button("設定に戻る") { withAnimation { step = .settings } }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private func convPartnerCard(turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("相手のセリフ", systemImage: "person.bubble.fill")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
            Text(turn.partnerEnglish)
                .font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text(turn.partnerJapanese)
                .font(.subheadline).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { convVM.speakPartner() } label: {
                Label("もう一度聞く", systemImage: "speaker.wave.2.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered).tint(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func convMyCard(turn: ConversationTurn) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("あなたの返答", systemImage: "person.fill")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)

            switch convVM.phase {
            case .partnerSpeaking:
                Button { convVM.showHintAndCountdown() } label: {
                    Text("ヒントを見てシンキングタイムへ")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).tint(.green)

            case .showHint, .thinkingCountdown:
                VStack(alignment: .leading, spacing: 10) {
                    Text(turn.myHintJapanese)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("英語で言ってみよう").font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        // カウントダウン円
                        ZStack {
                            Circle().stroke(Color.green.opacity(0.2), lineWidth: 3).frame(width: 40, height: 40)
                            Circle()
                                .trim(from: 0, to: CGFloat(convVM.countdown) / CGFloat(max(convVM.thinkingSeconds, 1)))
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: convVM.countdown)
                            Text("\(convVM.countdown)").font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                    Button { convVM.revealAnswer() } label: {
                        Text("答えを見る").frame(maxWidth: .infinity).padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }

            case .showAnswer, .nextReady:
                VStack(alignment: .leading, spacing: 8) {
                    Text(turn.myHintJapanese)
                        .font(.subheadline).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text(turn.myEnglish)
                        .font(.title3.weight(.bold)).foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                    if case .nextReady = convVM.phase {
                        Button { convVM.speakAnswer() } label: {
                            Label("もう一度聞く", systemImage: "speaker.wave.2.fill")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered).tint(.blue)
                    } else {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("読み上げ中…").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

            default: EmptyView()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - フラッシュカード内部UI（既存流用）

    private func learningContent(for card: WordCard) -> some View {
        VStack(spacing: 0) {
            progressSection
            Spacer()
            flashCard(for: card)
            Spacer()
            actionButtons(for: card)
            if viewModel.isShowingAnswer {
                evaluationButtons
            }
            navigationButtons
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.progressText)
                .font(.headline)
                .foregroundColor(.secondary)

            ProgressView(value: viewModel.progress)
                .tint(.blue)
        }
        .padding(.top)
    }

    private func flashCard(for card: WordCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.systemSecondaryBackgroundCompat)
                .shadow(radius: 5)

            VStack(spacing: 20) {
                statusBadge(for: card)

                Text(card.japanese)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if viewModel.isShowingAnswer {
                    Divider().padding(.horizontal, 40)
                    Text(card.english)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .padding(.horizontal, 20)
    }

    private func statusBadge(for card: WordCard) -> some View {
        HStack(spacing: 8) {
            Text(card.learningStatus.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor(for: card.learningStatus).opacity(0.15))
                .foregroundColor(statusColor(for: card.learningStatus))
                .cornerRadius(999)
            if let next = card.nextReviewAt {
                Text("次回: \(next.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func actionButtons(for card: WordCard) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                speechButton(title: "日本語", systemImage: "speaker.wave.2.fill") {
                    speechService.speak(card.japanese)
                }
                speechButton(title: viewModel.isShowingAnswer ? "英語" : "自動", systemImage: "speaker.wave.2") {
                    speechService.speak(viewModel.isShowingAnswer ? card.english : card.japanese)
                }
            }
            .padding(.horizontal, 20)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleAnswer()
                }
            } label: {
                Text(viewModel.isShowingAnswer ? "答えを隠す" : "答えを見る")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(viewModel.isShowingAnswer ? Color.orange : Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func speechButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity).padding()
                .background(Color.systemTertiaryBackgroundCompat)
                .cornerRadius(12)
        }
        .foregroundColor(.primary)
    }

    private var evaluationButtons: some View {
        HStack(spacing: 12) {
            ForEach(LearnCardEvaluation.allCases, id: \.title) { evaluation in
                Button {
                    if let updated = viewModel.applyEvaluation(evaluation) {
                        onUpdateCard?(updated)
                    }
                } label: {
                    Text(evaluation.title)
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(evaluation.color).cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var navigationButtons: some View {
        HStack(spacing: 20) {
            Button { viewModel.previousCard() } label: {
                HStack {
                    Image(systemName: "chevron.left"); Text("前へ")
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.systemTertiaryBackgroundCompat)
                .foregroundColor(viewModel.isFirstCard ? .gray : .primary)
                .cornerRadius(10)
            }
            .disabled(viewModel.isFirstCard)

            Button {
                if viewModel.isLastCard { viewModel.sessionCompleted = true }
                else { viewModel.nextCard() }
            } label: {
                HStack {
                    Text(viewModel.isLastCard ? "完了" : "次へ")
                    if !viewModel.isLastCard { Image(systemName: "chevron.right") }
                }
                .frame(maxWidth: .infinity).padding()
                .background(viewModel.isLastCard ? Color.green : Color.systemTertiaryBackgroundCompat)
                .foregroundColor(viewModel.isLastCard ? .white : .primary)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundColor(.green)
            Text("今回の学習が終わりました").font(.title3.bold())
            Button("もう一度") { viewModel.resetSession(with: cards); step = .settings }
                .buttonStyle(.borderedProminent)
            Button("閉じる") { dismiss() }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 60)).foregroundColor(.secondary)
            Text("学習するカードがありません").font(.headline)
            Button("閉じる") { dismiss() }.buttonStyle(.borderedProminent)
        }
    }

    private func statusColor(for status: LearningStatus) -> Color {
        switch status {
        case .new: return .blue
        case .notSure: return .orange
        case .reviewing: return .purple
        case .mastered: return .green
        }
    }
}

// MARK: - モード enum

enum LearnPracticeMode {
    case flashcard
    case conversation
}

#Preview {
    LearnModeView(cards: [
        WordCard(collectionId: UUID(), japanese: "おはよう", english: "Good morning"),
        WordCard(collectionId: UUID(), japanese: "ありがとう", english: "Thank you"),
    ])
}
