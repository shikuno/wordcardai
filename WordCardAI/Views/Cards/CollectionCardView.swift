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

                    // 再生ボタン + 学習モードボタン（横並び）
                    playbackControlRow
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // 再生設定
                    playbackSettingsSection
                        .padding(.horizontal)
                        .padding(.top, 16)
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
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 上段：ステータスバッジ + 枚数
            HStack(alignment: .center) {
                if let card = playbackViewModel.currentCard {
                    Text(card.learningStatus.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(playbackViewModel.progressText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // 下段：ジャンプスライダー（10枚以上のとき表示）
            if playbackViewModel.cards.count >= 10 {
                cardJumpSlider
            }
        }
    }

    private var cardJumpSlider: some View {
        let total = playbackViewModel.cards.count
        // Slider は Double のみ受け付けるのでローカル Binding で変換
        let sliderBinding = Binding<Double>(
            get: { Double(playbackViewModel.currentIndex) },
            set: { newVal in
                let idx = Int(newVal.rounded())
                guard idx != playbackViewModel.currentIndex else { return }
                playbackViewModel.jumpTo(index: idx)
            }
        )

        return VStack(spacing: 2) {
            Slider(value: sliderBinding, in: 0...Double(total - 1), step: 1)
                .tint(.blue)
            HStack {
                Text("1枚目")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(total)枚目")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Card Carousel
    // Instagram/メルカリ型: カードは画面幅の80%、左右に8pxの隙間+前後カードが細く見える

    private var cardCarouselSection: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 10          // 現在カードと前後カードの間の隙間
            let peekWidth: CGFloat = 14    // 前後カードのチラ見え幅
            let cardWidth = geometry.size.width - (peekWidth + gap) * 2

            ZStack(alignment: .center) {
                // 前カード（左・細く見える）
                if playbackViewModel.canGoPrevious {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .frame(width: cardWidth, height: 290)
                        .offset(x: -(cardWidth + gap * 2))
                }

                // 次カード（右・細く見える）
                if playbackViewModel.canGoNext {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(uiColor: .tertiarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .frame(width: cardWidth, height: 290)
                        .offset(x: cardWidth + gap * 2)
                }

                // 現在カード（中央・前面）
                mainCardView(cardWidth: cardWidth)
            }
            .frame(width: geometry.size.width, height: 310)
        }
        .frame(height: 310)
    }

    // MARK: - Main Card

    private func mainCardView(cardWidth: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)

            VStack(spacing: 16) {
                Spacer()

                if let card = playbackViewModel.currentCard {
                    Text(card.japanese)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

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

                if showFlipHint {
                    Text("タップで裏返す")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: cardWidth, height: 290)
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

    // MARK: - Playback Controls（再生・学習モードを横並び）

    private var playbackControlRow: some View {
        HStack(spacing: 10) {
            Button {
                if playbackViewModel.isPlaying {
                    playbackViewModel.stopPlayback()
                } else {
                    playbackViewModel.startPlayback()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: playbackViewModel.isPlaying ? "stop.fill" : "play.fill")
                    Text(playbackViewModel.isPlaying ? "停止" : "再生")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showingLearnMode = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "graduationcap.fill")
                    Text("学習")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
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

            // 再生スピード（ボタン選択）
            VStack(alignment: .leading, spacing: 8) {
                Text("再生スピード")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                let presets: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { rate in
                        let isSelected = abs(playbackViewModel.playbackRate - rate) < 0.01
                        Button {
                            playbackViewModel.playbackRate = rate
                        } label: {
                            Text(String(format: "%.2gx", rate))
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.blue : Color(uiColor: .tertiarySystemBackground))
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 自動送り待ち時間（カスタム刻み）
            VStack(alignment: .leading, spacing: 8) {
                Text("自動送り: \(playbackViewModel.autoAdvanceDelayText)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // 0〜3秒は0.5刻み、3〜6秒は1秒刻み、6〜10秒は2秒刻み
                let delaySteps: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(delaySteps, id: \.self) { sec in
                            let isSelected = abs(playbackViewModel.autoAdvanceDelay - sec) < 0.01
                            Button {
                                playbackViewModel.autoAdvanceDelay = sec
                            } label: {
                                Text(sec == 0 ? "なし" : "\(sec.formatted())秒")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.blue : Color(uiColor: .tertiarySystemBackground))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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


