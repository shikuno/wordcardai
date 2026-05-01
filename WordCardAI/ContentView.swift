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
    @EnvironmentObject var appUpdateService: AppUpdateService
    @Environment(\.openURL) private var openURL

    var body: some View {
        TabView {
            CollectionsListView(storage: UserDefaultsStorage(), cardsViewModel: cardsViewModel)
                .tabItem {
                    Label("デッキ", systemImage: "rectangle.stack.fill")
                }

            AIChatView()
                .tabItem {
                    Label("AI相談", systemImage: "bubble.left.and.bubble.right.fill")
                }
        }
        .task {
            await appUpdateService.checkForUpdatesIfNeeded()
        }
        .alert("新しいバージョンがあります", isPresented: updateAlertBinding) {
            Button("アップデート") {
                if let url = appUpdateService.availableUpdate?.trackViewURL {
                    openURL(url)
                }
                appUpdateService.markCurrentUpdateAsNotified()
            }
            Button("あとで", role: .cancel) {
                appUpdateService.markCurrentUpdateAsNotified()
            }
        } message: {
            if let update = appUpdateService.availableUpdate,
               let notes = update.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text("バージョン \(update.version) が利用できます。\n\n\(notes)")
            } else if let update = appUpdateService.availableUpdate {
                Text("バージョン \(update.version) が利用できます。App Store で更新してください。")
            } else {
                Text("新しいバージョンが利用できます。App Store で更新してください。")
            }
        }
    }

    private var updateAlertBinding: Binding<Bool> {
        Binding(
            get: { appUpdateService.availableUpdate != nil },
            set: { isPresented in
                if !isPresented, appUpdateService.availableUpdate != nil {
                    appUpdateService.markCurrentUpdateAsNotified()
                }
            }
        )
    }
}

#Preview {
    // プレビュー用の簡易モック
    let storage = UserDefaultsStorage()
    let settings = SettingsService(storage: storage)
    let collectionsVM = CollectionsViewModel(storage: storage)
    let cardsVM = CardsViewModel(storage: storage)
    let appUpdateService = AppUpdateService(settingsService: settings)
    
    return ContentView()
        .environmentObject(settings)
        .environmentObject(collectionsVM)
        .environmentObject(cardsVM)
        .environmentObject(appUpdateService)
}
