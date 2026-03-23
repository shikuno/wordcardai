import SwiftUI

// サポートする言語の一覧
private let supportedLanguages: [(code: String, label: String)] = [
    ("ja", "日本語"),
    ("en", "英語"),
    ("zh", "中国語"),
    ("ko", "韓国語"),
    ("fr", "フランス語"),
    ("de", "ドイツ語"),
    ("es", "スペイン語"),
    ("it", "イタリア語"),
    ("pt", "ポルトガル語"),
    ("ru", "ロシア語"),
]

private func langLabel(_ code: String) -> String {
    supportedLanguages.first(where: { $0.code == code })?.label ?? code
}

struct CreateEditCardView: View {
    @Environment(\.dismiss) private var dismiss
    let collection: CardCollection
    @ObservedObject var cardsViewModel: CardsViewModel
    @ObservedObject var settingsService: SettingsService

    @StateObject private var viewModel: CreateCardViewModel
    @FocusState private var focusedField: Field?

    let card: WordCard?
    private let isEditing: Bool

    @State private var debugTapCount = 0
    @State private var showDebugAlert = false
    @State private var showLanguagePicker = false

    enum Field { case front, back, note }

    init(collection: CardCollection, cardsViewModel: CardsViewModel, settingsService: SettingsService, card: WordCard?) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.settingsService = settingsService
        self.card = card
        self.isEditing = card != nil

        let s = settingsService.settings
        _viewModel = StateObject(wrappedValue: CreateCardViewModel(
            translationService: TranslationServiceFactory.createService(settings: s),
            naturalExpressionCount: s.candidateCount,
            frontLanguage: s.frontLanguage,
            backLanguage: s.backLanguage
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                languageHeaderSection
                frontSection
                translateButtonSection
                if !viewModel.back.isEmpty || !viewModel.front.isEmpty {
                    backSection
                }
                if viewModel.canGenerateExpressions {
                    naturalExpressionsButtonSection
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
                focusedField = .front
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage { Text(error) }
            }
        }
    }

    // MARK: - 言語設定ヘッダー

    private var languageHeaderSection: some View {
        Section {
            // 表面言語 ⇄ 裏面言語
            HStack(spacing: 0) {
                languageTag(
                    label: "表面",
                    language: viewModel.frontLanguage,
                    color: .blue
                ) { code in
                    viewModel.frontLanguage = code
                    settingsService.updateFrontLanguage(code)
                }

                Spacer()

                // 翻訳方向トグルボタン
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleDirection()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                        Text(viewModel.translateFrontToBack ? "表→裏" : "裏→表")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                languageTag(
                    label: "裏面",
                    language: viewModel.backLanguage,
                    color: .orange
                ) { code in
                    viewModel.backLanguage = code
                    settingsService.updateBackLanguage(code)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("言語設定")
        } footer: {
            Text("翻訳方向ボタンで表面↔裏面の翻訳元を切り替えられます")
        }
    }

    @ViewBuilder
    private func languageTag(label: String, language: String, color: Color, onSelect: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(supportedLanguages, id: \.code) { lang in
                Button(lang.label) { onSelect(lang.code) }
            }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(langLabel(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 表面セクション

    private var frontSection: some View {
        Section {
            TextField("入力してください", text: $viewModel.front, axis: .vertical)
                .focused($focusedField, equals: .front)
                .lineLimit(3...6)
        } header: {
            HStack {
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Text("表面（\(langLabel(viewModel.frontLanguage))）")
            }
        }
    }

    // MARK: - 翻訳ボタン

    private var translateButtonSection: some View {
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
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("\(viewModel.sourceLabel)から\(viewModel.targetLabel)へ翻訳")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)
        }
    }

    // MARK: - 裏面セクション

    private var backSection: some View {
        Section {
            TextField("入力してください", text: $viewModel.back, axis: .vertical)
                .focused($focusedField, equals: .back)
                .lineLimit(3...6)
        } header: {
            HStack {
                Circle().fill(Color.orange).frame(width: 8, height: 8)
                Text("裏面（\(langLabel(viewModel.backLanguage))）")
            }
        } footer: {
            Text("直接編集もできます")
        }
    }

    // MARK: - 自然な表現ボタン

    private var naturalExpressionsButtonSection: some View {
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
            Text("AIがネイティブらしい\(langLabel(viewModel.targetLanguage))表現を提案します")
        }
    }

    // MARK: - 自然な表現一覧

    @ViewBuilder
    private var naturalExpressionsSection: some View {
        Section {
            ForEach(Array(viewModel.naturalExpressions.enumerated()), id: \.offset) { index, expr in
                Button {
                    viewModel.selectExpression(at: index)
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
