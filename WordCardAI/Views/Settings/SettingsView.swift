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
    
    var body: some View {
        Form {
            aiSettingsSection
            dataSection
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
    }
    
    private var aiSettingsSection: some View {
        Section {
            Picker("候補数", selection: $settingsService.settings.candidateCount) {
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
            Text("日本語入力時に生成する英語候補の数を設定します")
        }
    }
    
    private var dataSection: some View {
        Section {
            HStack {
                Text("カード集数")
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
    
    private var appInfoSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text("1.0.0")
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
