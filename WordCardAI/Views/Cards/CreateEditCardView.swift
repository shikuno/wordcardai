import SwiftUI

struct CreateEditCardView: View {
    @Environment(\.dismiss) private var dismiss
    let collection: CardCollection
    @ObservedObject var cardsViewModel: CardsViewModel
    @ObservedObject var settingsService: SettingsService

    @StateObject private var viewModel: CreateCardViewModel
    private let speechService = SpeechService.shared
    @FocusState private var focusedField: Field?

    let card: WordCard?
    private let isEditing: Bool

    @State private var debugTapCount = 0
    @State private var showDebugAlert = false

    enum Field { case input, english, note }

    init(collection: CardCollection, cardsViewModel: CardsViewModel, settingsService: SettingsService, card: WordCard?) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.settingsService = settingsService
        self.card = card
        self.isEditing = card != nil

        _viewModel = StateObject(wrappedValue: CreateCardViewModel(
            translationService: TranslationServiceFactory.createService(settings: settingsService.settings),
            naturalExpressionCount: settingsService.settings.candidateCount
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                step1Button
                if !viewModel.english.isEmpty {
                    englishSection
                }
                if viewModel.canGenerateExpressions {
                    step2Button
                }
                if !viewModel.naturalExpressions.isEmpty {
                    naturalExpressionsSection
                }
                optionalFieldsSection
            }
            .navigationTitle(isEditing ? "カード編集" : "カード作成")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCard() }
                        .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                if let card { viewModel.loadCard(card) }
                focusedField = .input
            }
            .onDisappear { speechService.stop() }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }

    // MARK: - 入力セクション

    private var inputSection: some View {
        Section {
            TextField("テキストを入力", text: $viewModel.inputText, axis: .vertical)
                .focused($focusedField, equals: .input)
                .lineLimit(3...6)

            Button {
                speechService.speak(viewModel.inputText)
            } label: {
                Label("読み上げ", systemImage: "speaker.wave.2.fill")
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("入力テキスト *")
        } footer: {
            Text("日本語・英語など言語は問いません")
        }
    }

    // MARK: - Step1: 翻訳ボタン

    private var step1Button: some View {
        Section {
            Button {
                focusedField = nil
                Task { await viewModel.translateOnce() }
            } label: {
                HStack {
                    if viewModel.isTranslating {
                        ProgressView().padding(.trailing, 4)
                        Text("翻訳中...")
                    } else {
                        Image(systemName: "globe")
                        Text("翻訳する")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)
        }
    }

    // MARK: - 英語セクション（Step1 完了後に表示）

    private var englishSection: some View {
        Section {
            TextField("翻訳結果", text: $viewModel.english, axis: .vertical)
                .focused($focusedField, equals: .english)
                .lineLimit(3...6)

            Button {
                speechService.speak(viewModel.english)
            } label: {
                Label("読み上げ", systemImage: "speaker.wave.2")
            }
            .disabled(viewModel.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } header: {
            Text("翻訳結果 *")
        } footer: {
            Text("直接編集もできます")
        }
    }

    // MARK: - Step2: 自然な表現ボタン

    private var step2Button: some View {
        Section {
            Button {
                focusedField = nil
                Task { await viewModel.generateNaturalExpressions() }
            } label: {
                HStack {
                    if viewModel.isGeneratingExpressions {
                        ProgressView().padding(.trailing, 4)
                        Text("生成中...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("自然な表現を見る（\(settingsService.settings.candidateCount)件）")
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .disabled(viewModel.isGeneratingExpressions)
        } footer: {
            Text("AIがネイティブらしい言い回しを提案します")
        }
    }

    // MARK: - 自然な表現一覧（Step2 完了後に表示）

    @ViewBuilder
    private var naturalExpressionsSection: some View {
        Section {
            ForEach(Array(viewModel.naturalExpressions.enumerated()), id: \.offset) { index, expr in
                Button {
                    viewModel.selectExpression(at: index)
                    // 2番目を10回連続タップでデバッグ表示
                    if index == 1 {
                        debugTapCount += 1
                        if debugTapCount >= 10 {
                            debugTapCount = 0
                            showDebugAlert = true
                        }
                    } else {
                        debugTapCount = 0
                    }
                } label: {
                    HStack {
                        Text(expr).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: viewModel.selectedExpressionIndex == index
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedExpressionIndex == index ? .blue : .gray)
                    }
                }
            }
        } header: {
            Text("自然な表現（AI候補）")
        }
        .alert("AI生出力（デバッグ）", isPresented: $showDebugAlert) {
            Button("コピー") {
                UIPasteboard.general.string = viewModel.rawAIOutput ?? "(なし)"
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(viewModel.rawAIOutput ?? "(まだ生成していません)")
        }
    }

    // MARK: - オプション欄

    private var optionalFieldsSection: some View {
        Section {
            TextField("メモを入力（任意）", text: $viewModel.note, axis: .vertical)
                .focused($focusedField, equals: .note)
                .lineLimit(2...4)
        } header: {
            Text("メモ（任意）")
        }
    }

    // MARK: - 保存

    private func saveCard() {
        if isEditing, let existingCard = card {
            let updated = viewModel.updateCard(existingCard)
            cardsViewModel.updateCard(updated)
        } else {
            if let newCard = viewModel.createCard(for: collection.id) {
                cardsViewModel.createCard(newCard)
            }
        }
        dismiss()
    }
}

#Preview {
    CreateEditCardView(
        collection: CardCollection(title: "日常会話"),
        cardsViewModel: CardsViewModel(storage: UserDefaultsStorage()),
        settingsService: SettingsService(storage: UserDefaultsStorage()),
        card: nil
    )
}
