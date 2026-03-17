//
//  CollectionCardView.swift
//  WordCardAI
//
//  Created by Copilot on 2026/03/17.
//

import SwiftUI

struct CollectionCardView: View {
    let collection: CardCollection
    @ObservedObject var cardsViewModel: CardsViewModel
    @ObservedObject var collectionsViewModel: CollectionsViewModel
    @EnvironmentObject var settingsService: SettingsService

    @StateObject private var playbackViewModel: CollectionPlaybackViewModel
    @State private var showingList = false
    @State private var showingCreateCard = false
    @State private var showingLearnMode = false
    @GestureState private var dragOffset: CGFloat = 0

    init(collection: CardCollection, cardsViewModel: CardsViewModel, collectionsViewModel: CollectionsViewModel) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.collectionsViewModel = collectionsViewModel

        let cards = cardsViewModel.cards(for: collection.id)
        _playbackViewModel = StateObject(wrappedValue: CollectionPlaybackViewModel(cards: cards))
    }

    var body: some View {
        VStack(spacing: 16) {
            if playbackViewModel.cards.isEmpty {
                emptyStateView
            } else {
                headerSection
                actionShortcutSection
                cardSection
                playbackSettingsSection
                controlSection
            }
        }
        .padding()
        .navigationTitle(collection.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("一覧") {
                    showingList = true
                }
                Button {
                    showingCreateCard = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            refreshCards()
        }
        .onDisappear {
            playbackViewModel.stopPlayback()
        }
        .sheet(isPresented: $showingList, onDismiss: refreshCards) {
            NavigationStack {
                CardsListView(
                    collection: collection,
                    cardsViewModel: cardsViewModel,
                    collectionsViewModel: collectionsViewModel
                )
                .environmentObject(settingsService)
            }
        }
        .sheet(isPresented: $showingCreateCard, onDismiss: refreshCards) {
            CreateEditCardView(
                collection: collection,
                cardsViewModel: cardsViewModel,
                settingsService: settingsService,
                card: nil
            )
        }
        .sheet(isPresented: $showingLearnMode, onDismiss: refreshCards) {
            LearnModeView(cards: cardsViewModel.cards(for: collection.id)) { updatedCard in
                cardsViewModel.replaceCard(updatedCard)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(playbackViewModel.progressText)
                .font(.headline)
                .foregroundColor(.secondary)

            if let card = playbackViewModel.currentCard {
                HStack(spacing: 8) {
                    Text(card.learningStatus.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(999)
                    if let nextReviewAt = card.nextReviewAt {
                        Text("次回: \(nextReviewAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var actionShortcutSection: some View {
        HStack(spacing: 12) {
            Button {
                showingCreateCard = true
            } label: {
                Label("新規カード追加", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingList = true
            } label: {
                Label("一覧で編集", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var cardSection: some View {
        VStack(spacing: 14) {
            if let card = playbackViewModel.currentCard {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.systemSecondaryBackgroundCompat)
                        .shadow(radius: 6)

                    VStack(spacing: 18) {
                        Text(playbackViewModel.isShowingBack ? "裏面" : "表面")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text(card.japanese)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if playbackViewModel.isShowingBack {
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
                .frame(height: 340)
                .offset(x: dragOffset)
                .rotationEffect(.degrees(Double(dragOffset / 20)))
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        playbackViewModel.toggleSide()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            playbackViewModel.handleSwipe(translation: value.translation.width)
                        }
                )
            }

            VStack(spacing: 6) {
                Label("カードをタップで表裏切替", systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Label("右へスワイプで前へ", systemImage: "arrow.left")
                    Label("左へスワイプで次へ", systemImage: "arrow.right")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("再生モード")
                .font(.headline)

            Picker("読み上げ対象", selection: $playbackViewModel.speechTarget) {
                ForEach(PlaybackSpeechTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("再生スピード")
                        .font(.subheadline)
                    Spacer()
                    Text(playbackViewModel.playbackSpeedLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $playbackViewModel.playbackRate, in: 0.3...0.72, step: 0.02)
                HStack {
                    Text("ゆっくり")
                    Spacer()
                    Text("標準")
                    Spacer()
                    Text("速い")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("次のカードまでの待ち時間: \(playbackViewModel.autoAdvanceDelay, specifier: "%.1f")秒")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: $playbackViewModel.autoAdvanceDelay, in: 0.2...2.0, step: 0.1)
            }
        }
        .padding()
        .background(Color.systemSecondaryBackgroundCompat)
        .cornerRadius(16)
    }

    private var controlSection: some View {
        HStack(spacing: 12) {
            Button {
                if playbackViewModel.isPlaying {
                    playbackViewModel.stopPlayback()
                } else {
                    playbackViewModel.startPlayback()
                }
            } label: {
                Label(playbackViewModel.isPlaying ? "停止" : "再生", systemImage: playbackViewModel.isPlaying ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingLearnMode = true
            } label: {
                Label("学習モード", systemImage: "graduationcap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("このカード集にはまだカードがありません")
                .font(.headline)
            Text("まずはカードを追加して、あとから一覧で編集できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("カードを追加") {
                showingCreateCard = true
            }
            .buttonStyle(.borderedProminent)
            Button("一覧を開く") {
                showingList = true
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func refreshCards() {
        cardsViewModel.loadAllCards()
        playbackViewModel.updateCards(cardsViewModel.cards(for: collection.id))
    }
}
