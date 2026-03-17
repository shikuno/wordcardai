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

struct LearnModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LearnModeViewModel()
    private let speechService = SpeechService.shared

    let cards: [WordCard]
    let onUpdateCard: ((WordCard) -> Void)?

    init(cards: [WordCard], onUpdateCard: ((WordCard) -> Void)? = nil) {
        self.cards = cards
        self.onUpdateCard = onUpdateCard
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyStateView
                } else if viewModel.cards.isEmpty || !viewModel.isConfigured {
                    sessionSetupView
                } else if let card = viewModel.currentCard, !viewModel.sessionCompleted {
                    learningContent(for: card)
                } else {
                    completionView
                }
            }
            .padding()
            .navigationTitle("学習モード")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        speechService.stop()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.cards.isEmpty {
                        Button(action: { viewModel.resetSession(with: cards) }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.prepare(with: cards)
            }
            .onDisappear {
                speechService.stop()
            }
        }
    }

    private var sessionSetupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("出題設定")
                        .font(.title2.bold())
                    Text("問題数と学習モードを選んで開始できます。")
                        .foregroundColor(.secondary)
                }

                // 問題数
                VStack(alignment: .leading, spacing: 12) {
                    Text("問題数")
                        .font(.headline)
                    Picker("問題数", selection: $viewModel.questionCount) {
                        ForEach(viewModel.availableQuestionCounts(for: cards), id: \.self) { count in
                            Text("\(count)問").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
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
                                HStack(spacing: 6) {
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

                // 開始位置（忘却曲線モード以外で表示）
                if viewModel.mode != .spacedRepetition {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("開始位置")
                            .font(.headline)
                        ForEach(LearnStartPosition.allCases) { pos in
                            let selected = viewModel.startFrom == pos
                            Button {
                                viewModel.startFrom = pos
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: pos.icon)
                                        .frame(width: 24)
                                        .foregroundColor(selected ? .blue : .secondary)
                                    Text(pos.title)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(Color.systemSecondaryBackgroundCompat)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 学習モード
                VStack(alignment: .leading, spacing: 12) {
                    Text("学習モード")
                        .font(.headline)
                    ForEach(LearnSessionMode.allCases) { mode in
                        Button {
                            viewModel.mode = mode
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: viewModel.mode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(viewModel.mode == mode ? .blue : .secondary)
                            }
                            .padding()
                            .background(Color.systemSecondaryBackgroundCompat)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }

                learningSummaryCard

                Button {
                    viewModel.startSession(with: cards)
                } label: {
                    Text("\(viewModel.questionCount)問で開始")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
        }
    }

    private var learningSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("学習対象", systemImage: "chart.bar.fill")
                .font(.headline)
            Text("全 \(cards.count) 枚")
            Text("復習期限が来ているカード: \(viewModel.dueCardCount(in: cards)) 枚")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.systemSecondaryBackgroundCompat)
        .cornerRadius(14)
    }

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
        VStack(spacing: 20) {
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
                        Divider()
                            .padding(.horizontal, 40)

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

            if let nextReviewAt = card.nextReviewAt {
                Text("次回: \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    let text = viewModel.isShowingAnswer ? card.english : card.japanese
                    speechService.speak(text)
                }
            }
            .padding(.horizontal, 20)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleAnswer()
                }
            }) {
                Text(viewModel.isShowingAnswer ? "答えを隠す" : "答えを見る")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
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
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.systemTertiaryBackgroundCompat)
                .cornerRadius(12)
        }
        .foregroundColor(.primary)
    }

    private var evaluationButtons: some View {
        HStack(spacing: 12) {
            ForEach(LearnCardEvaluation.allCases, id: \.title) { evaluation in
                Button {
                    guard let updatedCard = viewModel.applyEvaluation(evaluation) else { return }
                    onUpdateCard?(updatedCard)
                } label: {
                    Text(evaluation.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(evaluation.color)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var navigationButtons: some View {
        HStack(spacing: 20) {
            Button(action: { viewModel.previousCard() }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("前へ")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.systemTertiaryBackgroundCompat)
                .foregroundColor(viewModel.isFirstCard ? .gray : .primary)
                .cornerRadius(10)
            }
            .disabled(viewModel.isFirstCard)

            Button(action: {
                if viewModel.isLastCard {
                    viewModel.sessionCompleted = true
                } else {
                    viewModel.nextCard()
                }
            }) {
                HStack {
                    Text(viewModel.isLastCard ? "完了" : "次へ")
                    if !viewModel.isLastCard {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
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
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("今回の学習が終わりました")
                .font(.title3.bold())

            Button("もう一度出題する") {
                viewModel.resetSession(with: cards)
            }
            .buttonStyle(.borderedProminent)

            Button("閉じる") {
                dismiss()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("学習するカードがありません")
                .font(.headline)

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func statusColor(for status: LearningStatus) -> Color {
        switch status {
        case .new:
            return .blue
        case .notSure:
            return .orange
        case .reviewing:
            return .purple
        case .mastered:
            return .green
        }
    }
}

#Preview {
    LearnModeView(cards: [
        WordCard(collectionId: UUID(), japanese: "おはよう", english: "Good morning"),
        WordCard(collectionId: UUID(), japanese: "ありがとう", english: "Thank you"),
        WordCard(collectionId: UUID(), japanese: "さようなら", english: "Goodbye")
    ])
}
