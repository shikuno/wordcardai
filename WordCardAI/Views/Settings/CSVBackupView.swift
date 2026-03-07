//
//  CSVBackupView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2026/03/07.
//

import SwiftUI
import UniformTypeIdentifiers

struct CSVBackupView: View {
    @EnvironmentObject var cardsViewModel: CardsViewModel
    @EnvironmentObject var collectionsViewModel: CollectionsViewModel
    @Environment(\.dismiss) private var dismiss

    // エクスポート
    @State private var exportItem: CSVFile?
    @State private var showExporter = false

    // インポート
    @State private var showImporter = false
    @State private var selectedCollectionId: UUID?

    // アラート
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var importSuccessCount = 0

    var body: some View {
        NavigationStack {
            Form {
                exportSection
                importSection
            }
            .navigationTitle("CSV バックアップ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            // エクスポート
            .fileExporter(
                isPresented: $showExporter,
                document: exportItem,
                contentType: .commaSeparatedText,
                defaultFilename: exportFileName()
            ) { result in
                switch result {
                case .success:
                    alertMessage = "CSVファイルをエクスポートしました"
                case .failure(let error):
                    alertMessage = "エクスポート失敗: \(error.localizedDescription)"
                }
                showAlert = true
            }
            // インポート
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("完了", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("全カードを CSV ファイルとして書き出します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("カラム: id / collectionId / japanese / english / candidates / note / tags / createdAt")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            Button {
                prepareExport()
            } label: {
                Label("全カードをエクスポート", systemImage: "square.and.arrow.up")
            }
            .disabled(totalCardCount == 0)
        } header: {
            Text("エクスポート")
        } footer: {
            Text("合計 \(totalCardCount) 枚のカードが対象です")
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("CSV ファイルを読み込んで単語帳にカードを追加します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("先頭のヘッダー行は自動でスキップされます。collectionId 列が有効な UUID であればそのコレクションに追加されます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            // インポート先のコレクションを選択
            Picker("インポート先", selection: $selectedCollectionId) {
                Text("自動（CSV の collectionId を使用）").tag(UUID?.none)
                ForEach(collectionsViewModel.collections) { collection in
                    Text(collection.title).tag(UUID?.some(collection.id))
                }
            }

            Button {
                showImporter = true
            } label: {
                Label("CSV ファイルを読み込む", systemImage: "square.and.arrow.down")
            }
            .disabled(collectionsViewModel.collections.isEmpty)
        } header: {
            Text("インポート")
        } footer: {
            if collectionsViewModel.collections.isEmpty {
                Text("インポートするには、先に単語帳を作成してください")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Helpers

    private var totalCardCount: Int {
        collectionsViewModel.collections.reduce(0) {
            $0 + cardsViewModel.cardCount(for: $1.id)
        }
    }

    private func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "wordcards_\(formatter.string(from: Date())).csv"
    }

    private func prepareExport() {
        cardsViewModel.loadAllCards()
        // allCards は private なので CardsViewModel 経由で全コレクションのカードを集める
        var allCards: [WordCard] = []
        for collection in collectionsViewModel.collections {
            cardsViewModel.loadCards(for: collection.id)
            allCards.append(contentsOf: cardsViewModel.cards)
        }
        let csv = CSVService.export(cards: allCards)
        exportItem = CSVFile(content: csv)
        showExporter = true
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            alertMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            showAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw CSVError.emptyFile
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let csvString = try String(contentsOf: url, encoding: .utf8)
                // インポート先 collectionId: ピッカーで選択されていれば優先、なければ CSV の値を使う
                let fallbackId = collectionsViewModel.collections.first?.id ?? UUID()
                let targetId = selectedCollectionId ?? fallbackId
                let cards = try CSVService.import(csvString: csvString, into: targetId)

                for card in cards {
                    // selectedCollectionId が指定されている場合は強制的に上書き
                    let finalCard: WordCard
                    if let overrideId = selectedCollectionId {
                        finalCard = WordCard(
                            id: card.id,
                            collectionId: overrideId,
                            japanese: card.japanese,
                            english: card.english,
                            candidates: card.candidates,
                            note: card.note,
                            tags: card.tags,
                            createdAt: card.createdAt
                        )
                    } else {
                        finalCard = card
                    }
                    cardsViewModel.createCard(finalCard)
                }

                alertMessage = "\(cards.count) 枚のカードをインポートしました"
                showAlert = true
            } catch {
                alertMessage = "インポート失敗: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

// MARK: - FileDocument for export

struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    CSVBackupView()
        .environmentObject(CardsViewModel(storage: UserDefaultsStorage()))
        .environmentObject(CollectionsViewModel(storage: UserDefaultsStorage()))
}
