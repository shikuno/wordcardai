//
//  StorageProtocol.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

protocol StorageProtocol {
    // Card collections
    func saveCollections(_ collections: [CardCollection]) throws
    func loadCollections() throws -> [CardCollection]

    // Word cards
    func saveCards(_ cards: [WordCard]) throws
    func loadCards() throws -> [WordCard]

    // App settings
    func saveSettings(_ settings: AppSettings) throws
    func loadSettings() throws -> AppSettings
}
