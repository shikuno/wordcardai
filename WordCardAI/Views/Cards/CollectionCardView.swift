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
    @State private var showFlipHint = false

    init(collection: CardCollection, cardsViewModel: CardsViewModel, collectionsViewModel: CollectionsViewModel) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.collectionsViewModel = collectionsViewModel

        let cards = cardsViewModel.cards(for: collection.id)
        _playbackViewModel = StateObject(wrappedValue: CollectionPlaybackViewModel(cards: cards))
    }

    var body: some View {
        VStack(spacing: 18) {
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
                Button {
                    showingCreateCard = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    showingList = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .onAppear {
            refreshCards()
            playbackViewModel.playbackRate = settingsService.settings.playbackRate
            playbackViewModel.autoAdvanceDelay = settingsService.settings.playbackAutoAdvanceDelay
            playbackViewModel.speechTarget = PlaybackSpeechTarget(rawValue: settingsService.settings.playbackSpeechTargetRawValue) ?? .frontOnly
            showFlipHint = !settingsService.settings.hasSeenCardFlipHint
        }
        .onChange(of: playbackViewModel.playbackRate) { _, newValue in
            settingsService.updatePlaybackRate(newValue)
        }
        .onChange(of: playbackViewModel.autoAdvanceDelay) { _, newValue in
            settingsService.updatePlaybackAutoAdvanceDelay(newValue)
        }
        .onChange(of: playbackViewModel.speechTarget) { _, newValue in
            settingsService.updatePlaybackSpeechTarget(newValue.rawValue)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(collection.title)
                    .font(.title2.bold())
                    .lineLimit(2)
                Spacer(minLength: 16)
                Text(playbackViewModel.progressText)
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

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
                    Spacer()
                    Text("全 \(playbackViewModel.cards.count) 枚")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var actionShortcutSection: some View {
        HStack(spacing: 10) {
            smartActionChip(title: "追加", systemImage: "plus.circle") {
                showingCreateCard = true
            }
            smartActionChip(title: "編集", systemImage: "square.and.pencil") {
                showingList = true
            }
            Spacer()
        }
    }

    private func smartActionChip(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.systemSecondaryBackgroundCompat)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var cardSection: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.82
            let sideWidth = geometry.size.width * 0.12

            ZStack {
                if playbackViewModel.canGoPrevious {
                    sidePreviewCard(direction: .previous)
                        .frame(width: sideWidth)
                        .offset(x: -(cardWidth / 2 + sideWidth * 0.55))
                }

                currentInteractiveCard(width: cardWidth)

                if playbackViewModel.canGoNext {
                    sidePreviewCard(direction: .next)
                        .frame(width: sideWidth)
                        .offset(x: cardWidth / 2 + sideWidth * 0.55)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 370)
    }

    private func currentInteractiveCard(width: CGFloat) -> some View {
        let card = playbackViewModel.currentCard

        return ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.systemSecondaryBackgroundCompat)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            if let card {
                VStack(spacing: 18) {
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

            if showFlipHint {
                VStack {
                    Spacer()
                    Label("タップで表裏切替", systemImage: "hand.tap")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                }
                .transition(.opacity)
            }
        }
        .frame(width: width, height: 350)
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset / 24)))
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                playbackViewModel.toggleSide()
                if showFlipHint {
                    showFlipHint = false
                    settingsService.updateHasSeenCardFlipHint(true)
                }
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

    private func sidePreviewCard(direction: SidePreviewDirection) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.systemTertiaryBackgroundCompat)
            .overlay {
                Image(systemName: direction == .previous ? "chevron.left" : "chevron.right")
                    .foregroundColor(.secondary)
            }
            .opacity(0.9)
            .frame(height: 280)
    }

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("再生モード")
                .font(.headline)

            Picker("読み上げ対象", selection: $playbackViewModel.speechTarget) {
                ForEach(PlaybackSpeechTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("再生スピード")
                        .font(.subheadline)
                    Spacer()
                    Text(playbackViewModel.playbackSpeedText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.systemTertiaryBackgroundCompat)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    ForEach(playbackViewModel.playbackPresets, id: \.self) { preset in
                        Button {
                            playbackViewModel.playbackRate = preset
                        } label: {
                            Text(String(format: "%.1fx", preset))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(abs(playbackViewModel.playbackRate - preset) < 0.01 ? Color.blue : Color.systemTertiaryBackgroundCompat)
                                .foregroundColor(abs(playbackViewModel.playbackRate - preset) < 0.01 ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("次のカードまでの待ち時間: \(playbackViewModel.autoAdvanceDelayText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: $playbackViewModel.autoAdvanceDelay, in: 0...10, step: 0.5)
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
            Spacer()
        }
    }

    private func refreshCards() {
        cardsViewModel.loadAllCards()
        playbackViewModel.updateCards(cardsViewModel.cards(for: collection.id))
    }
}

private enum SidePreviewDirection {
    case previous
    case next
}
