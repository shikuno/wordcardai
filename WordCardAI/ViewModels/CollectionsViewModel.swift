//
//  CollectionsViewModel.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CollectionsViewModel: ObservableObject {
    @Published var collections: [CardCollection] = []
    @Published var errorMessage: String?
    
    private let storage: StorageProtocol
    
    init(storage: StorageProtocol) {
        self.storage = storage
        loadCollections()
    }
    
    func loadCollections() {
        do {
            collections = try storage.loadCollections()
            collections.sort { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "カード集の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    func createCollection(title: String) {
        let newCollection = CardCollection(title: title)
        collections.insert(newCollection, at: 0)
        saveCollections()
    }
    
    func updateCollection(_ collection: CardCollection) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = collection
            saveCollections()
        }
    }
    
    func deleteCollection(_ collection: CardCollection) {
        collections.removeAll { $0.id == collection.id }
        saveCollections()
    }
    
    private func saveCollections() {
        do {
            try storage.saveCollections(collections)
        } catch {
            errorMessage = "カード集の保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
