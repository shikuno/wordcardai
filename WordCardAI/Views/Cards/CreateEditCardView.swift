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
            ScrollView {
                VStack(spacing: 20) {
                    frontCard
                    backCard
                    if !viewModel.naturalExpressions.isEmpty {
                        naturalExpressionsCard
                    }
                    noteField
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isEditing ? "カード編集" : "カード作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCard() }
                        .fontWeight(.semibold)
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

    // MARK: - 表面カード

    private var frontCard: some View {
        cardContainer {
            // ヘッダー：「表面」ラベル ＋ 言語選択
            cardHeader(title: "表面", langCode: viewModel.frontLanguage) { code in
                viewModel.frontLanguage = code
                settingsService.updateFrontLanguage(code)
            }

            // 入力欄（大きめ）
            TextField("ここに入力してください", text: $viewModel.front, axis: .vertical)
                .focused($focusedField, equals: .front)
                .lineLimit(4...10)
                .font(.body)
                .padding(.top, 4)

            Divider().padding(.top, 8)

            // 翻訳ボタン（入力欄の直下）
            translateFromFrontButton
        }
    }

    // MARK: - 裏面カード

    private var backCard: some View {
        cardContainer {
            // ヘッダー：「裏面」ラベル ＋ 言語選択
            cardHeader(title: "裏面", langCode: viewModel.backLanguage) { code in
                viewModel.backLanguage = code
                settingsService.updateBackLanguage(code)
            }

            // 入力欄
            TextField("翻訳するとここに入ります", text: $viewModel.back, axis: .vertical)
                .focused($focusedField, equals: .back)
                .lineLimit(4...10)
                .font(.body)
                .padding(.top, 4)

            // 裏面→表面の逆翻訳ボタン（小さめ・控えめ）
            if !viewModel.back.isEmpty {
                Divider().padding(.top, 8)
                translateFromBackButton
            }

            // 自然な表現ボタン（翻訳完了後に表示）
            if viewModel.canGenerateExpressions {
                Divider().padding(.top, 4)
                naturalExpressionsButton
            }
        }
    }

    // MARK: - 表面→裏面 翻訳ボタン

    private var translateFromFrontButton: some View {
        Button {
            focusedField = nil
            viewModel.translateFrontToBack = true
            Task { await viewModel.translateOnce() }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isTranslating && viewModel.translateFrontToBack {
                    ProgressView().scaleEffect(0.8)
                    Text("翻訳中…").foregroundColor(.secondary)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    Text("\(langLabel(viewModel.frontLanguage))→\(langLabel(viewModel.backLanguage))に翻訳")
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || viewModel.isTranslating)
    }

    // MARK: - 裏面→表面 逆翻訳ボタン（控えめ）

    private var translateFromBackButton: some View {
        Button {
            focusedField = nil
            viewModel.translateFrontToBack = false
            Task { await viewModel.translateOnce() }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isTranslating && !viewModel.translateFrontToBack {
                    ProgressView().scaleEffect(0.7)
                    Text("翻訳中…")
                } else {
                    Image(systemName: "arrow.up.circle")
                    Text("\(langLabel(viewModel.backLanguage))→\(langLabel(viewModel.frontLanguage))に翻訳")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || viewModel.isTranslating)
    }

    // MARK: - 自然な表現ボタン

    private var naturalExpressionsButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.generateNaturalExpressions() }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isGeneratingExpressions {
                    ProgressView().scaleEffect(0.8)
                    Text("生成中…").foregroundColor(.secondary)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("ネイティブらしい言い回しを見る")
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(settingsService.settings.candidateCount)件")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingExpressions)
    }

    // MARK: - 自然な表現一覧

    private var naturalExpressionsCard: some View {
        cardContainer {
            HStack {
                Image(systemName: "sparkles").foregroundColor(.purple)
                Text("AI候補").font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(Array(viewModel.naturalExpressions.enumerated()), id: \.offset) { index, expr in
                Button {
                    viewModel.selectExpression(at: index)
                    if index == 1 {
                        debugTapCount += 1
                        if debugTapCount >= 10 { debugTapCount = 0; showDebugAlert = true }
                    } else { debugTapCount = 0 }
                } label: {
                    HStack {
                        Text(expr)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if viewModel.selectedExpressionIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if index < viewModel.naturalExpressions.count - 1 {
                    Divider()
                }
            }
        }
        .alert("AI生出力（デバッグ）", isPresented: $showDebugAlert) {
            Button("コピー") { UIPasteboard.general.string = viewModel.rawAIOutput ?? "(なし)" }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(viewModel.rawAIOutput ?? "(まだ生成していません)")
        }
    }

    // MARK: - メモ欄

    private var noteField: some View {
        cardContainer {
            cardHeader(title: "メモ（任意）", langCode: nil, onSelect: nil)
            TextField("補足メモを書いておけます", text: $viewModel.note, axis: .vertical)
                .focused($focusedField, equals: .note)
                .lineLimit(2...5)
                .font(.body)
                .padding(.top, 4)
        }
    }

    // MARK: - 共通パーツ

    /// 白い角丸カード型コンテナ
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// カードヘッダー（タイトル ＋ 言語選択メニュー）
    @ViewBuilder
    private func cardHeader(title: String, langCode: String?, onSelect: ((String) -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Spacer()
            if let code = langCode, let onSelect {
                Menu {
                    ForEach(supportedLanguages, id: \.code) { lang in
                        Button {
                            onSelect(lang.code)
                        } label: {
                            if lang.code == code {
                                Label(lang.label, systemImage: "checkmark")
                            } else {
                                Text(lang.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(langLabel(code))
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - 保存

    private func saveCard() {
        if isEditing, let existingCard = card {
            cardsViewModel.updateCard(viewModel.updateCard(existingCard))
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
