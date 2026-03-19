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
            collections.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "デッキの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func createCollection(title: String) {
        let newCollection = CardCollection(title: title)
        collections.insert(newCollection, at: 0)
        saveCollections()
    }

    func updateCollection(_ collection: CardCollection) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            var updatedCollection = collection
            updatedCollection.updatedAt = Date()
            collections[index] = updatedCollection
            collections.sort { $0.updatedAt > $1.updatedAt }
            saveCollections()
        }
    }

    /// カードが追加・更新・削除された際に呼び出してデッキの更新日時を記録する
    func touchUpdatedAt(collectionId: UUID) {
        if let index = collections.firstIndex(where: { $0.id == collectionId }) {
            collections[index].updatedAt = Date()
            collections.sort { $0.updatedAt > $1.updatedAt }
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
            errorMessage = "デッキの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
