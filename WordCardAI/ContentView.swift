//
//  ContentView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct ContentView: View {
    // App から環境経由で渡される ViewModel やサービス
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var collectionsViewModel: CollectionsViewModel
    @EnvironmentObject var cardsViewModel: CardsViewModel
    
    var body: some View {
        // アプリのホーム画面としてコレクション一覧を表示
        CollectionsListView(storage: UserDefaultsStorage(), cardsViewModel: cardsViewModel)
    }
}

#Preview {
    // プレビュー用の簡易モック
    let storage = UserDefaultsStorage()
    let settings = SettingsService(storage: storage)
    let collectionsVM = CollectionsViewModel(storage: storage)
    let cardsVM = CardsViewModel(storage: storage)
    
    return ContentView()
        .environmentObject(settings)
        .environmentObject(collectionsVM)
        .environmentObject(cardsVM)
}
