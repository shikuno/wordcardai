import SwiftUI

struct CreateEditCardView: View {
    @Environment(\.dismiss) private var dismiss
    let collection: CardCollection
    @ObservedObject var cardsViewModel: CardsViewModel
    @ObservedObject var settingsService: SettingsService
    
    @StateObject private var viewModel: CreateCardViewModel
    @FocusState private var focusedField: Field?
    
    let card: WordCard?
    private let isEditing: Bool
    
    enum Field {
        case japanese, english, note, tags
    }
    
    init(collection: CardCollection, cardsViewModel: CardsViewModel, settingsService: SettingsService, card: WordCard?) {
        self.collection = collection
        self.cardsViewModel = cardsViewModel
        self.settingsService = settingsService
        self.card = card
        self.isEditing = card != nil
        
        _viewModel = StateObject(wrappedValue: CreateCardViewModel(
            translationService: TranslationServiceFactory.createService(settings: settingsService.settings),
            candidateCount: settingsService.settings.candidateCount
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                japaneseSection
                generateButton
                englishSection
                candidatesSection
                optionalFieldsSection
            }
            .navigationTitle(isEditing ? "カード編集" : "カード作成")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveCard()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .onAppear {
                if let card = card {
                    viewModel.loadCard(card)
                }
                focusedField = .japanese
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var japaneseSection: some View {
        Section {
            TextField("日本語を入力", text: $viewModel.japanese, axis: .vertical)
                .focused($focusedField, equals: .japanese)
                .lineLimit(3...6)
        } header: {
            Text("日本語 *")
        }
    }
    
    private var generateButton: some View {
        Section {
            Button(action: { generateCandidates() }) {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                            .padding(.trailing, 4)
                    } else {
                        Image(systemName: "lightbulb.fill")
                    }
                    Text(viewModel.isGenerating ? "生成中..." : "候補を生成")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(viewModel.japanese.isEmpty || viewModel.isGenerating)
        }
    }
    
    private var englishSection: some View {
        Section {
            TextField("英語を入力または候補から選択", text: $viewModel.english, axis: .vertical)
                .focused($focusedField, equals: .english)
                .lineLimit(3...6)
        } header: {
            Text("英語 *")
        } footer: {
            Text("候補から選択するか、直接編集できます")
        }
    }
    
    @ViewBuilder
    private var candidatesSection: some View {
        if !viewModel.candidates.isEmpty {
            Section {
                ForEach(Array(viewModel.candidates.enumerated()), id: \.offset) { index, candidate in
                    Button(action: { viewModel.selectCandidate(at: index) }) {
                        HStack {
                            Text(candidate)
                                .foregroundColor(.primary)
                            Spacer()
                            if viewModel.selectedCandidateIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            } header: {
                Text("AI候補")
            }
        }
    }
    
    private var optionalFieldsSection: some View {
        Group {
            Section {
                TextField("メモを入力（任意）", text: $viewModel.note, axis: .vertical)
                    .focused($focusedField, equals: .note)
                    .lineLimit(2...4)
            } header: {
                Text("メモ（任意）")
            }
            
            Section {
                TextField("タグをカンマ区切りで入力", text: $viewModel.tagsText)
                    .focused($focusedField, equals: .tags)
            } header: {
                Text("タグ（任意）")
            } footer: {
                Text("例: 挨拶, ビジネス, 旅行")
            }
        }
    }
    
    private func generateCandidates() {
        focusedField = nil
        Task {
            await viewModel.generateCandidates()
        }
    }
    
    private func saveCard() {
        if isEditing, let existingCard = card {
            let updatedCard = viewModel.updateCard(existingCard)
            cardsViewModel.updateCard(updatedCard)
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
