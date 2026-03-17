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

    private var cardSection: some View {
        VStack(spacing: 16) {
            if let card = playbackViewModel.currentCard {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.systemSecondaryBackgroundCompat)
                        .shadow(radius: 5)

                    VStack(spacing: 20) {
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
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 320)
            }

            Button(playbackViewModel.isShowingBack ? "表に戻す" : "裏を表示") {
                playbackViewModel.toggleSide()
            }
            .buttonStyle(.bordered)
        }
    }

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("再生モード")
                .font(.headline)

            Picker("スピード", selection: $playbackViewModel.playbackSpeed) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Text(speed.title).tag(speed)
                }
            }
            .pickerStyle(.segmented)

            Picker("読み上げ対象", selection: $playbackViewModel.speechTarget) {
                ForEach(PlaybackSpeechTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    playbackViewModel.goPrevious()
                } label: {
                    Label("前へ", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!playbackViewModel.canGoPrevious)

                Button {
                    playbackViewModel.goNext()
                } label: {
                    Label("次へ", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!playbackViewModel.canGoNext)
            }

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
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("このカード集にはまだカードがありません")
                .font(.headline)
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
