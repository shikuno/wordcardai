//
//  CSVBackupView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2026/03/07.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct CSVBackupView: View {
    @EnvironmentObject var cardsViewModel: CardsViewModel
    @EnvironmentObject var collectionsViewModel: CollectionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var exportItem: CSVFile?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportCollectionId: UUID?
    @State private var importCollectionId: UUID?
    @State private var resultMessage = ""
    @State private var skippedRows: [CSVImportSkippedRow] = []
    @State private var showResultAlert = false
    @State private var pendingImportResult: CSVImportResult?
    @State private var showImportPreview = false

    var body: some View {
        NavigationStack {
            Form {
                exportSection
                importSection
                if !skippedRows.isEmpty {
                    skippedRowsSection
                }
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
            .fileExporter(
                isPresented: $showExporter,
                document: exportItem,
                contentType: .commaSeparatedText,
                defaultFilename: exportFileName()
            ) { result in
                switch result {
                case .success:
                    resultMessage = "CSVファイルをエクスポートしました"
                case .failure(let error):
                    resultMessage = "エクスポート失敗: \(error.localizedDescription)"
                }
                showResultAlert = true
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("CSV 処理結果", isPresented: $showResultAlert) {
                Button("OK") {}
            } message: {
                Text(resultMessage)
            }
            .confirmationDialog("CSV を読み込みますか？", isPresented: $showImportPreview, titleVisibility: .visible) {
                Button("読み込む") {
                    executePendingImport()
                }
                Button("キャンセル", role: .cancel) {
                    clearPendingImport()
                }
            } message: {
                if let pendingImportResult {
                    Text(importPreviewMessage(for: pendingImportResult))
                }
            }
            .onDisappear {
                clearPendingImport()
            }
            .onAppear {
                cardsViewModel.loadAllCards()
                collectionsViewModel.loadCollections()
                if importCollectionId == nil {
                    importCollectionId = collectionsViewModel.collections.first?.id
                }
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            if !collectionsViewModel.collections.isEmpty {
                Picker("エクスポート対象", selection: $exportCollectionId) {
                    Text("すべてのコレクション").tag(UUID?.none)
                    ForEach(collectionsViewModel.collections) { collection in
                        Text(collection.title).tag(UUID?.some(collection.id))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("出力項目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Japanese, English")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            Button {
                prepareExport()
            } label: {
                Label("CSV をエクスポート", systemImage: "square.and.arrow.up")
            }
            .disabled(exportCards.isEmpty)
        } header: {
            Text("エクスポート")
        } footer: {
            Text("合計 \(exportCards.count) 枚のカードが対象です")
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("読み込み項目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Japanese, English を中心に読み込みます")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)

            Picker("インポート先", selection: $importCollectionId) {
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
            } else {
                Text("日本語と英語が入っていれば取り込みできます")
            }
        }
    }

    // MARK: - Skipped Rows Section

    private var skippedRowsSection: some View {
        Section {
            Button {
                copySkippedRowsSummary()
            } label: {
                Label("スキップ行をコピー", systemImage: "doc.on.doc")
            }

            ForEach(skippedRows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(row.rowNumber)行目: \(row.reason.description)")
                        .font(.subheadline)
                    if !row.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(row.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("スキップした行")
        } footer: {
            Text("フォーマット不正の行は読み込みを止めずにスキップします")
        }
    }

    // MARK: - Helpers

    private var exportCards: [WordCard] {
        if let exportCollectionId {
            return cardsViewModel.cards(for: exportCollectionId)
        }
        return cardsViewModel.allStoredCards()
    }

    private func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        if let exportCollectionId,
           let collection = collectionsViewModel.collections.first(where: { $0.id == exportCollectionId }) {
            return "wordcards_\(collection.title)_\(formatter.string(from: Date())).csv"
        }
        return "wordcards_all_\(formatter.string(from: Date())).csv"
    }

    private func prepareExport() {
        let csv = CSVService.export(cards: exportCards)
        exportItem = CSVFile(content: csv)
        showExporter = true
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            resultMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            skippedRows = []
            showResultAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let (csvString, didStartSecurityScope) = try readCSVString(from: url)
                defer {
                    if didStartSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let targetId = importCollectionId
                    ?? collectionsViewModel.collections.first?.id
                    ?? UUID()
                let importResult = try CSVService.import(csvString: csvString, into: targetId)

                pendingImportResult = importResult
                showImportPreview = true
            } catch {
                skippedRows = []
                resultMessage = "インポート失敗: \(error.localizedDescription)"
                showResultAlert = true
            }
        }
    }

    private func executePendingImport() {
        guard let pendingImportResult else {
            clearPendingImport()
            return
        }

        for card in pendingImportResult.importedCards {
            cardsViewModel.createCard(card)
        }
        cardsViewModel.loadAllCards()

        skippedRows = pendingImportResult.skippedRows
        resultMessage = "\(pendingImportResult.importedCount) 枚をインポートしました"
        if pendingImportResult.skippedCount > 0 {
            resultMessage += "\n\(pendingImportResult.skippedCount) 行をスキップしました"
        }
        clearPendingImport()
        showResultAlert = true
    }

    private func clearPendingImport() {
        pendingImportResult = nil
    }

    private func importPreviewMessage(for result: CSVImportResult) -> String {
        var lines = [
            "取り込み予定: \(result.importedCount) 件",
            "スキップ予定: \(result.skippedCount) 件"
        ]
        if let collection = collectionsViewModel.collections.first(where: { $0.id == importCollectionId }) {
            lines.append("保存先: \(collection.title)")
        }
        if let firstSkipped = result.skippedRows.first {
            lines.append("例: \(firstSkipped.rowNumber)行目は \(firstSkipped.reason.description)")
        }
        return lines.joined(separator: "\n")
    }

    private func readCSVString(from url: URL) throws -> (String, Bool) {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        let csvString = try String(contentsOf: url, encoding: .utf8)
        return (csvString, didStartSecurityScope)
    }

    private func copySkippedRowsSummary() {
        let summary = skippedRows
            .map { row in
                let raw = row.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty {
                    return "\(row.rowNumber)行目: \(row.reason.description)"
                }
                return "\(row.rowNumber)行目: \(row.reason.description)\n\(raw)"
            }
            .joined(separator: "\n\n")

        #if os(iOS)
        UIPasteboard.general.string = summary
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        #endif

        resultMessage = "スキップした行をコピーしました"
        showResultAlert = true
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
