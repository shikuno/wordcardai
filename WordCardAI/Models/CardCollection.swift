//
//  CardCollection.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

struct CardCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
