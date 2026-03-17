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
    @State private var editingCard: WordCard?
    @State private var showingSpeedPicker = false

    init(collection: CardCollection, cardsViewModel: CardsViewModel, collectionsViewModel: CollectionsViewModel) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.collectionsViewModel = collectionsViewModel

        let cards = cardsViewModel.cards(for: collection.id)
        _playbackViewModel = StateObject(wrappedValue: CollectionPlaybackViewModel(cards: cards))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
            .padding(.bottom, 24)
        }
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
        .sheet(item: $editingCard, onDismiss: refreshCards) { card in
            CreateEditCardView(
                collection: collection,
                cardsViewModel: cardsViewModel,
                settingsService: settingsService,
                card: card
            )
        }
        .sheet(isPresented: $showingSpeedPicker) {
            NavigationStack {
                List {
                    Section("再生スピード") {
                        ForEach(playbackViewModel.playbackPresets, id: \.self) { preset in
                            Button {
                                playbackViewModel.playbackRate = preset
                                showingSpeedPicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(String(format: "%.2gx", preset))
                                            .foregroundColor(.primary)
                                        Text(speedDescription(for: preset))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if abs(playbackViewModel.playbackRate - preset) < 0.01 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("再生スピード")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            showingSpeedPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
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
            smartActionChip(title: "一覧 / 編集", systemImage: "square.and.pencil") {
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
            let cardWidth = min(geometry.size.width * 0.88, 430)
            let peekOffset = cardWidth * 0.54

            ZStack {
                if playbackViewModel.canGoPrevious {
                    edgePeekCard(direction: .previous)
                        .frame(width: cardWidth, height: 340)
                        .offset(x: -peekOffset)
                }

                currentInteractiveCard(width: cardWidth)

                if playbackViewModel.canGoNext {
                    edgePeekCard(direction: .next)
                        .frame(width: cardWidth, height: 340)
                        .offset(x: peekOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 380)
    }

    private func edgePeekCard(direction: SidePreviewDirection) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.systemTertiaryBackgroundCompat)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            .mask(alignment: direction == .previous ? .trailing : .leading) {
                Rectangle()
                    .frame(width: 18)
            }
            .opacity(0.95)
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

            VStack(alignment: .leading, spacing: 10) {
                Text("再生スピード")
                    .font(.subheadline)

                Button {
                    showingSpeedPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playbackViewModel.playbackSpeedText)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(playbackViewModel.playbackSpeedLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .background(Color.systemTertiaryBackgroundCompat)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
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
                showingLearnMode = true
            } label: {
                Label("学習モード", systemImage: "graduationcap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func currentInteractiveCard(width: CGFloat) -> some View {
        let card = playbackViewModel.currentCard

        return ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.systemSecondaryBackgroundCompat)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)

            if let card {
                VStack(spacing: 18) {
                    Spacer(minLength: 12)

                    Text(card.japanese)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

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

                    Spacer(minLength: 12)
                }
                .padding(.vertical)
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
        .scaleEffect(1 - min(abs(dragOffset) / 1200, 0.04))
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

    private func speedDescription(for rate: Double) -> String {
        switch rate {
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
