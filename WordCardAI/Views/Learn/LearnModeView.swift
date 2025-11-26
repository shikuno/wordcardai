//
//  LearnModeView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

// Cross-platform color helpers
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
    
    let cards: [WordCard]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let card = viewModel.currentCard {
                    progressSection
                    Spacer()
                    flashCard(for: card)
                    Spacer()
                    actionButtons
                    navigationButtons
                } else {
                    emptyStateView
                }
            }
            .padding()
            .navigationTitle("学習モード")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.reset() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadCards(cards)
            }
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
                    Text(card.japanese)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding()

                    if viewModel.isShowingAnswer {
                        Divider()
                            .padding(.horizontal, 40)

                        Text(card.english)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding()
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .padding(.horizontal, 20)
        }
    }

    private var actionButtons: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.toggleAnswer()
            }
        }) {
            Text(viewModel.isShowingAnswer ? "もう一度" : "答えを見る")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isShowingAnswer ? Color.orange : Color.blue)
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
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
                    dismiss()
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
        .padding(.bottom, 20)
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
}

#Preview {
    LearnModeView(cards: [
        WordCard(collectionId: UUID(), japanese: "おはよう", english: "Good morning"),
        WordCard(collectionId: UUID(), japanese: "ありがとう", english: "Thank you"),
        WordCard(collectionId: UUID(), japanese: "さようなら", english: "Goodbye")
    ])
}
