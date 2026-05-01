import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

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

    @State private var showDeleteConfirm = false
    @State private var showErrorDialog = false
    @State private var showErrorDebugSheet = false
    @State private var didTriggerErrorDebugLongPress = false

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
                    noteField
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isEditing ? "カード編集" : "カード作成")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                if isEditing {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                    #else
                    ToolbarItem {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                    #endif
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCard() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $viewModel.showCandidatePicker) {
                CandidatePickerSheet(
                    title: viewModel.pickerTitle,
                    candidates: viewModel.pickerCandidates,
                    targetLabel: viewModel.pickerTargetIsFront ? "表面" : "裏面",
                    debugInfo: viewModel.rawAIOutput,
                    onSelect: { viewModel.applyCandidate($0) },
                    onCancel: { viewModel.showCandidatePicker = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog("このカードを削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    if let existingCard = card {
                        cardsViewModel.deleteCard(existingCard)
                    }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除したカードは元に戻せません")
            }
            .onAppear {
                if let card { viewModel.loadCard(card) }
                focusedField = .front
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorDialog = (newValue != nil)
            }
            .overlay {
                if showErrorDialog, let error = viewModel.errorMessage {
                    errorOverlay(message: error)
                }
            }
            .sheet(isPresented: $showErrorDebugSheet) {
                NavigationStack {
                    ScrollView {
                        Text(viewModel.rawAIOutput ?? "(デバッグ情報なし)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                    .navigationTitle("エラーデバッグ情報")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") {
                                showErrorDebugSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("コピー") {
                                #if os(iOS)
                                UIPasteboard.general.string = viewModel.rawAIOutput ?? "(デバッグ情報なし)"
                                #elseif os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(viewModel.rawAIOutput ?? "(デバッグ情報なし)", forType: .string)
                                #endif
                            }
                        }
                    }
                }
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

            Divider()
                .padding(.top, 8)

            // 翻訳 ＋ 言い換えを横並びに
            HStack(spacing: 12) {
                translateFromFrontButton
                Divider().frame(height: 28)
                naturalExpressionsButton
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
    }

    // MARK: - 裏面カード

    private var backCard: some View {
        cardContainer {
            cardHeader(title: "裏面", langCode: viewModel.backLanguage) { code in
                viewModel.backLanguage = code
                settingsService.updateBackLanguage(code)
            }

            TextField("翻訳するとここに入ります", text: $viewModel.back, axis: .vertical)
                .focused($focusedField, equals: .back)
                .lineLimit(4...10)
                .font(.body)
                .padding(.top, 4)

            Divider()
                .padding(.top, 8)

            // 逆翻訳 ＋ 言い換えを常に表示
            HStack(spacing: 12) {
                translateFromBackButton
                Divider().frame(height: 28)
                naturalExpressionsReverseButton
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
    }

    // MARK: - 表面→裏面 翻訳ボタン

    private var translateFromFrontButton: some View {
        Button {
            focusedField = nil
            viewModel.translateFrontToBack = true
            Task { await viewModel.translateOnce() }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isTranslating && viewModel.translateFrontToBack {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                }
                Text("翻訳")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)
    }

    // MARK: - 裏面→表面 逆翻訳ボタン

    private var translateFromBackButton: some View {
        Button {
            focusedField = nil
            viewModel.translateFrontToBack = false
            Task { await viewModel.translateOnce() }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isTranslating && !viewModel.translateFrontToBack {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                }
                Text("翻訳")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslating)
    }

    // MARK: - 自然な表現ボタン（表面→裏面）

    private var naturalExpressionsButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.generateNaturalExpressions() }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isGeneratingExpressions {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("AIで自然な表現を生成")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGeneratingExpressions)
    }

    // MARK: - 自然な表現ボタン（裏面→表面）

    private var naturalExpressionsReverseButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.generateNaturalExpressionsReverse() }
        } label: {
            HStack(spacing: 4) {
                if viewModel.isGeneratingExpressionsReverse {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("AIで自然な表現を生成")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGeneratingExpressionsReverse)
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

    // MARK: - 削除

    private func deleteCard() {
        if let existingCard = card {
            cardsViewModel.deleteCard(existingCard)
        }
        dismiss()
    }

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("エラー")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if didTriggerErrorDebugLongPress {
                        didTriggerErrorDebugLongPress = false
                        return
                    }
                    showErrorDialog = false
                    viewModel.errorMessage = nil
                } label: {
                    Text("OK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 5)
                        .onEnded { _ in
                            didTriggerErrorDebugLongPress = true
                            showErrorDebugSheet = true
                        }
                )
            }
            .padding(18)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
        }
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
