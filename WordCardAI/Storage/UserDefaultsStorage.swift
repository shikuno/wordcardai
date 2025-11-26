import Foundation

class UserDefaultsStorage: StorageProtocol {
    private let userDefaults = UserDefaults.standard
    
    private let collectionsKey = "WordCardAI.collections.v1"
    private let cardsKey = "WordCardAI.cards.v1"
    private let settingsKey = "WordCardAI.settings.v1"
    
    func saveCollections(_ collections: [CardCollection]) throws {
        let data = try JSONEncoder().encode(collections)
        userDefaults.set(data, forKey: collectionsKey)
    }
    
    func loadCollections() throws -> [CardCollection] {
        guard let data = userDefaults.data(forKey: collectionsKey) else {
            return []
        }
        return try JSONDecoder().decode([CardCollection].self, from: data)
    }
    
    func saveCards(_ cards: [WordCard]) throws {
        let data = try JSONEncoder().encode(cards)
        userDefaults.set(data, forKey: cardsKey)
    }
    
    func loadCards() throws -> [WordCard] {
        guard let data = userDefaults.data(forKey: cardsKey) else {
            return []
        }
        return try JSONDecoder().decode([WordCard].self, from: data)
    }
    
    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        userDefaults.set(data, forKey: settingsKey)
    }
    
    func loadSettings() throws -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return AppSettings()
        }
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}