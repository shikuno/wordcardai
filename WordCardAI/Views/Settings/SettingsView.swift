//
//  SettingsView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var cardsViewModel: CardsViewModel
    @EnvironmentObject var collectionsViewModel: CollectionsViewModel

    @State private var showCSVBackup = false

    var body: some View {
        Form {
            aiSettingsSection
            dataSection
            csvSection
            appInfoSection
        }
        .navigationTitle("設定")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showCSVBackup) {
            CSVBackupView()
                .environmentObject(cardsViewModel)
                .environmentObject(collectionsViewModel)
        }
    }
    
    private var aiSettingsSection: some View {
        Section {
            Picker("表面の言語", selection: $settingsService.settings.frontLanguage) {
                ForEach(supportedLanguageCodes, id: \.code) { lang in
                    Text(lang.label).tag(lang.code)
                }
            }
            .onChange(of: settingsService.settings.frontLanguage) { _, newValue in
                settingsService.updateFrontLanguage(newValue)
            }

            Picker("裏面の言語", selection: $settingsService.settings.backLanguage) {
                ForEach(supportedLanguageCodes, id: \.code) { lang in
                    Text(lang.label).tag(lang.code)
                }
            }
            .onChange(of: settingsService.settings.backLanguage) { _, newValue in
                settingsService.updateBackLanguage(newValue)
            }

            Picker("自然な表現の候補数", selection: $settingsService.settings.candidateCount) {
                ForEach(1...5, id: \.self) { count in
                    Text("\(count)件").tag(count)
                }
            }
            .onChange(of: settingsService.settings.candidateCount) { _, newValue in
                settingsService.updateCandidateCount(newValue)
            }
        } header: {
            Text("AI設定")
        } footer: {
            Text("カード作成画面での翻訳方向のデフォルト言語を設定します。「自然な表現を見る」の候補数も変更できます")
        }
    }

    private let supportedLanguageCodes: [(code: String, label: String)] = [
        ("ja", "日本語"), ("en", "英語"), ("zh", "中国語"), ("ko", "韓国語"),
        ("fr", "フランス語"), ("de", "ドイツ語"), ("es", "スペイン語"),
        ("it", "イタリア語"), ("pt", "ポルトガル語"), ("ru", "ロシア語"),
    ]
    
    private var dataSection: some View {
        Section {
            HStack {
                Text("デッキ数")
                Spacer()
                Text("\(collectionsViewModel.collections.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("カード総数")
                Spacer()
                Text("\(totalCardCount)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("データ")
        }
    }
    
    private var csvSection: some View {
        Section {
            Button {
                showCSVBackup = true
            } label: {
                Label("CSV バックアップ／インポート", systemImage: "doc.text")
            }
        } header: {
            Text("データ管理")
        } footer: {
            Text("全カードを CSV 形式でエクスポートしたり、CSV ファイルから単語帳にインポートできます")
        }
    }

    private var appInfoSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("2.0")
                    .foregroundColor(.secondary)
            }
            
            Link(destination: URL(string: "https://www.apple.com")!) {
                HStack {
                    Text("プライバシーポリシー")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("アプリ情報")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("WordCardAI は、英会話中に思いついた日本語を手軽に記録し、AIで英語候補を生成して単語カードを作成するアプリです。")
                Text("すべてのデータは端末内にのみ保存され、外部サーバーには送信されません。")
            }
            .font(.caption)
        }
    }
    
    private var totalCardCount: Int {
        collectionsViewModel.collections.reduce(0) { total, collection in
            total + cardsViewModel.cardCount(for: collection.id)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SettingsService(storage: UserDefaultsStorage()))
            .environmentObject(CardsViewModel(storage: UserDefaultsStorage()))
            .environmentObject(CollectionsViewModel(storage: UserDefaultsStorage()))
    }
}
