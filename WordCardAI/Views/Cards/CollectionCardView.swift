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
            VStack(spacing: 0) {
                if playbackViewModel.cards.isEmpty {
                    emptyStateView
                } else {
                    // ヘッダー：コレクション名・枚数・学習状態
                    headerSection
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // カードエリア（前後チラ見え）
                    cardCarouselSection

                    // 再生ボタン（カードのすぐ下）
                    playbackControlRow
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 再生設定
                    playbackSettingsSection
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 学習モード
                    Button {
                        showingLearnMode = true
                    } label: {
                        Label("学習モード", systemImage: "graduationcap.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
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

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if let card = playbackViewModel.currentCard {
                    Text(card.learningStatus.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            Spacer()
            Text(playbackViewModel.progressText)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Card Carousel

    private var cardCarouselSection: some View {
        GeometryReader { geometry in
            // 中央カードは画面幅の 84%、左右に各 ~8% ずつはみ出させる
            let cardWidth = geometry.size.width * 0.84
            let sideOffset = (geometry.size.width - cardWidth) / 2

            ZStack(alignment: .center) {
                // 前カード（背面・左）
                if playbackViewModel.canGoPrevious {
                    peekCard
                        .frame(width: cardWidth, height: 300)
                        .offset(x: -(cardWidth * 0.5 + sideOffset * 0.6))
                }

                // 次カード（背面・右）
                if playbackViewModel.canGoNext {
                    peekCard
                        .frame(width: cardWidth, height: 300)
                        .offset(x: cardWidth * 0.5 + sideOffset * 0.6)
                }

                // 現在カード（前面）
                mainCardView(cardWidth: cardWidth)
            }
            .frame(width: geometry.size.width, height: 320)
        }
        .frame(height: 320)
        // 左右クリッピングをオフにして前後カードがはみ出して見えるようにする
        .clipped(antialiased: false)
    }

    /// 前後にチラ見えさせるダミーカード（中身なし・角丸のみ）
    private var peekCard: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(uiColor: .secondarySystemBackground))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Main Card

    private func mainCardView(cardWidth: CGFloat) -> some View {
        ZStack {
            // カード背景
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)

            // カード内コンテンツ
            VStack(spacing: 16) {
                Spacer()

                if let card = playbackViewModel.currentCard {
                    // 表面（日本語）
                    Text(card.japanese)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // 裏面（英語）
                    if playbackViewModel.isShowingBack {
                        Divider().padding(.horizontal, 40)
                        Text(card.english)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }

                Spacer()

                // タップヒント（初回のみ）
                if showFlipHint {
                    Text("タップで裏返す")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: cardWidth, height: 300)
        .offset(x: dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
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

    // MARK: - Playback Controls

    /// 再生ボタン（カードの外・直下）
    private var playbackControlRow: some View {
        HStack(spacing: 12) {
            Button {
                if playbackViewModel.isPlaying {
                    playbackViewModel.stopPlayback()
                } else {
                    playbackViewModel.startPlayback()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: playbackViewModel.isPlaying ? "stop.fill" : "play.fill")
                    Text(playbackViewModel.isPlaying ? "停止" : "再生")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Settings

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("再生設定")
                .font(.headline)

            // 読み上げ対象
            Picker("読み上げ対象", selection: $playbackViewModel.speechTarget) {
                ForEach(PlaybackSpeechTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            // 再生スピード（タップでシート）
            Button {
                showingSpeedPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("再生スピード")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(playbackViewModel.playbackSpeedText)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // 次カードまでの待ち時間
            VStack(alignment: .leading, spacing: 6) {
                Text("自動送り: \(playbackViewModel.autoAdvanceDelayText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Slider(value: $playbackViewModel.autoAdvanceDelay, in: 0...10, step: 0.5)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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


