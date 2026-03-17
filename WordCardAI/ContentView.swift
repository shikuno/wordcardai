//
//  ContentView.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var collectionsViewModel: CollectionsViewModel
    @EnvironmentObject var cardsViewModel: CardsViewModel

    var body: some View {
        TabView {
            CollectionsListView(storage: UserDefaultsStorage(), cardsViewModel: cardsViewModel)
                .tabItem {
                    Label("カード集", systemImage: "rectangle.stack.fill")
                }

            AIChatView()
                .tabItem {
                    Label("AI相談", systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
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
