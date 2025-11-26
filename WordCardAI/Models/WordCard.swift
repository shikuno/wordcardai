//
//  WordCard.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

struct WordCard: Identifiable, Codable, Equatable {
    let id: UUID
    var collectionId: UUID
    var japanese: String
    var english: String
    var candidates: [String]
    var note: String?
    var tags: [String]
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        collectionId: UUID,
        japanese: String,
        english: String,
        candidates: [String] = [],
        note: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.collectionId = collectionId
        self.japanese = japanese
        self.english = english
        self.candidates = candidates
        self.note = note
        self.tags = tags
        self.createdAt = createdAt
    }
}
