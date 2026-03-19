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
    @State private var showingDisplaySettings = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var showFlipHint = false
    @State private var editingCard: WordCard?
    @State private var showBackFirst = false
    @State private var filterStatuses: Set<LearningStatus> = Set(LearningStatus.allCases)

    init(collection: CardCollection, cardsViewModel: CardsViewModel, collectionsViewModel: CollectionsViewModel) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.collectionsViewModel = collectionsViewModel

        let cards = cardsViewModel.cards(for: collection.id)
        _playbackViewModel = StateObject(wrappedValue: CollectionPlaybackViewModel(cards: cards, collectionId: collection.id.uuidString))
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
                    Image(systemName: "rectangle.stack.fill")
                }
                Button {
                    showingDisplaySettings = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear {
            refreshCards()
            playbackViewModel.playbackRate = settingsService.settings.playbackRate
            playbackViewModel.autoAdvanceDelay = settingsService.settings.playbackAutoAdvanceDelay
            playbackViewModel.frontToBackDelay = settingsService.settings.playbackFrontToBackDelay
            playbackViewModel.speechTarget = PlaybackSpeechTarget(rawValue: settingsService.settings.playbackSpeechTargetRawValue) ?? .frontOnly
            showFlipHint = !settingsService.settings.hasSeenCardFlipHint
        }
        .onChange(of: playbackViewModel.playbackRate) { _, newValue in
            settingsService.updatePlaybackRate(newValue)
        }
        .onChange(of: playbackViewModel.autoAdvanceDelay) { _, newValue in
            settingsService.updatePlaybackAutoAdvanceDelay(newValue)
        }
        .onChange(of: playbackViewModel.frontToBackDelay) { _, newValue in
            settingsService.updatePlaybackFrontToBackDelay(newValue)
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
                    collectionsViewModel: collectionsViewModel,
                    onSelectCard: { card in
                        // 選択カードにジャンプしてシートを閉じる
                        if let idx = playbackViewModel.cards.firstIndex(where: { $0.id == card.id }) {
                            playbackViewModel.jumpTo(index: idx)
                        }
                        showingList = false
                    }
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
        .sheet(isPresented: $showingDisplaySettings) {
            DisplaySettingsSheet(
                showBackFirst: $showBackFirst,
                filterStatuses: $filterStatuses,
                allCards: playbackViewModel.allCards,
                onApply: { statuses in
                    playbackViewModel.applyFilter(statuses: statuses)
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            if playbackViewModel.cards.count >= 10 {
                cardJumpSlider
            }
        }
    }

    private var cardJumpSlider: some View {
        let total = playbackViewModel.cards.count
        return VStack(spacing: 4) {
            GeometryReader { geo in
                let trackW = geo.size.width
                let progress: CGFloat = total > 1
                    ? CGFloat(playbackViewModel.currentIndex) / CGFloat(total - 1)
                    : 0
                let thumbX = trackW * progress

                ZStack(alignment: .leading) {
                    // トラック背景
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 3)
                    // 進捗バー
                    Capsule()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: thumbX, height: 3)
                    // つまみ（小さい白丸）
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .offset(x: thumbX - 5)
                }
                .frame(height: 10)
                .contentShape(Rectangle().inset(by: -10))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let ratio = max(0, min(1, val.location.x / trackW))
                            let idx = Int((ratio * Double(total - 1)).rounded())
                            if idx != playbackViewModel.currentIndex {
                                playbackViewModel.jumpTo(index: idx)
                            }
                        }
                )
            }
            .frame(height: 10)
            // 枚数表示（スライダー下・中央）
            Text(playbackViewModel.progressText)
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Card Carousel
    // HStack全カード横並び + currentIndex変化でスライドアニメーション

    private var cardCarouselSection: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 12
            let peekWidth: CGFloat = 16
            let cardWidth = geometry.size.width - (peekWidth + gap) * 2

            // 全カードを横に並べ、currentIndex分だけオフセット
            let stride = cardWidth + gap
            let baseOffset = (geometry.size.width - cardWidth) / 2
            let scrollOffset = baseOffset - CGFloat(playbackViewModel.currentIndex) * stride

            HStack(spacing: gap) {
                ForEach(Array(playbackViewModel.cards.enumerated()), id: \.offset) { idx, card in
                    cardCell(card: card, idx: idx, cardWidth: cardWidth, isCurrent: idx == playbackViewModel.currentIndex)
                }
            }
            .offset(x: scrollOffset + dragOffset)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: playbackViewModel.currentIndex)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: dragOffset)
            .frame(height: 310)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .updating($dragOffset) { value, state, _ in
                        // 端のカードでは引っ張り抵抗をかける
                        let raw = value.translation.width
                        if (raw > 0 && !playbackViewModel.canGoPrevious) ||
                           (raw < 0 && !playbackViewModel.canGoNext) {
                            state = raw * 0.25
                        } else {
                            state = raw
                        }
                    }
                    .onEnded { value in
                        playbackViewModel.handleSwipe(translation: value.translation.width)
                    }
            )
        }
        .frame(height: 310)
    }

    // 1枚のカードセル
    private func cardCell(card: WordCard, idx: Int, cardWidth: CGFloat, isCurrent: Bool) -> some View {
        // 裏から表示モード：表裏を反転
        let showingBack = isCurrent && (showBackFirst
            ? !playbackViewModel.isShowingBack
            :  playbackViewModel.isShowingBack)

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

            // ── テキスト中央 ──
            VStack(spacing: 0) {
                Spacer()
                if showingBack {
                    adaptiveText(card.english, maxLength: 60)
                        .padding(.horizontal, 24)
                        .opacity(isCurrent ? 1.0 : 0.4)
                } else {
                    adaptiveText(card.japanese, maxLength: 60)
                        .padding(.horizontal, 24)
                        .opacity(isCurrent ? 1.0 : 0.4)
                }
                Spacer()
            }
        }
        // ── ステータスバッジ（左上）・編集ボタン（右上）をoverlay ──
        .overlay(alignment: .topLeading) {
            if isCurrent {
                Text(card.learningStatus.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusColor(card.learningStatus).opacity(0.12))
                    .foregroundColor(statusColor(card.learningStatus))
                    .clipShape(Capsule())
                    .padding(14)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isCurrent {
                Button { editingCard = card } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .padding(12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCurrent else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                playbackViewModel.toggleSide()
                if showFlipHint {
                    showFlipHint = false
                    settingsService.updateHasSeenCardFlipHint(true)
                }
            }
        }
        .frame(width: cardWidth, height: 290)
    }

    /// 文字数に応じてフォントサイズを自動調整
    private func adaptiveText(_ text: String, maxLength: Int) -> some View {
        let len = text.count
        let uiFont: UIFont = len <= 20 ? .boldSystemFont(ofSize: 28)
                           : len <= 40 ? .boldSystemFont(ofSize: 22)
                           : len <= 80 ? .boldSystemFont(ofSize: 18)
                           :             .boldSystemFont(ofSize: 15)
        return CardTextLabel(
            text: text,
            font: uiFont,
            color: .label,
            alignment: .center
        )
    }

    private func statusColor(_ status: LearningStatus) -> Color {
        switch status {
        case .new:       return .blue
        case .notSure:   return .orange
        case .reviewing: return .purple
        case .mastered:  return .green
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("再生設定")
                .font(.headline)

            // 読み上げ対象
            Picker("読み上げ対象", selection: $playbackViewModel.speechTarget) {
                ForEach(PlaybackSpeechTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)

            // 再生スピード（スライダー）
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("再生スピード")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(playbackViewModel.playbackSpeedText)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
                HStack(spacing: 8) {
                    Text("0.25x").font(.caption2).foregroundColor(.secondary)
                    Slider(value: $playbackViewModel.playbackRate, in: 0.25...2.0, step: 0.25)
                        .tint(.blue)
                    Text("2.0x").font(.caption2).foregroundColor(.secondary)
                }
            }

            // タイミング（2列グリッドピッカー）
            let timingSteps: [Double] = [0, 0.5, 1, 1.5, 2, 3, 5]

            HStack(alignment: .top, spacing: 12) {
                // 表裏切替の間隔
                VStack(alignment: .leading, spacing: 6) {
                    Text("表裏の切替まで")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Menu {
                        ForEach(timingSteps, id: \.self) { sec in
                            Button {
                                playbackViewModel.frontToBackDelay = sec
                            } label: {
                                HStack {
                                    Text(sec == 0 ? "すぐ" : String(format: sec.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f秒" : "%.1f秒", sec))
                                    if abs(playbackViewModel.frontToBackDelay - sec) < 0.01 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(playbackViewModel.frontToBackDelay == 0 ? "すぐ" : String(format: playbackViewModel.frontToBackDelay.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f秒" : "%.1f秒", playbackViewModel.frontToBackDelay))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: .infinity)

                // 裏→次カードの間隔
                VStack(alignment: .leading, spacing: 6) {
                    Text("次のカードまで")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Menu {
                        ForEach(timingSteps, id: \.self) { sec in
                            Button {
                                playbackViewModel.autoAdvanceDelay = sec
                            } label: {
                                HStack {
                                    Text(sec == 0 ? "すぐ" : String(format: sec.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f秒" : "%.1f秒", sec))
                                    if abs(playbackViewModel.autoAdvanceDelay - sec) < 0.01 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(playbackViewModel.autoAdvanceDelay == 0 ? "すぐ" : String(format: playbackViewModel.autoAdvanceDelay.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f秒" : "%.1f秒", playbackViewModel.autoAdvanceDelay))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: .infinity)
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


