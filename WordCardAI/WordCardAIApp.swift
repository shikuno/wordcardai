import SwiftUI

@main
struct WordCardAIApp: App {
    // 永続ストレージは ObservableObject ではないので通常のプロパティとして保持
    private let storage: StorageProtocol = UserDefaultsStorage()
    
    // 画面全体で共有する ObservableObject だけを StateObject で管理
    @StateObject private var settingsService: SettingsService
    @StateObject private var collectionsViewModel: CollectionsViewModel
    @StateObject private var cardsViewModel: CardsViewModel
    @StateObject private var appUpdateService: AppUpdateService
    
    init() {
        let storage = UserDefaultsStorage()
        let settingsService = SettingsService(storage: storage)
        let collectionsVM = CollectionsViewModel(storage: storage)
        let cardsVM = CardsViewModel(storage: storage)
        let appUpdateService = AppUpdateService(settingsService: settingsService)
        cardsVM.collectionsViewModel = collectionsVM   // カード操作時にデッキのupdatedAtを更新
        _settingsService = StateObject(wrappedValue: settingsService)
        _collectionsViewModel = StateObject(wrappedValue: collectionsVM)
        _cardsViewModel = StateObject(wrappedValue: cardsVM)
        _appUpdateService = StateObject(wrappedValue: appUpdateService)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsService)
                .environmentObject(collectionsViewModel)
                .environmentObject(cardsViewModel)
                .environmentObject(appUpdateService)
        }
    }
}
