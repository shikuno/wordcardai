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
    var learningStatus: LearningStatus
    var reviewCount: Int
    var correctCount: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        collectionId: UUID,
        japanese: String,
        english: String,
        candidates: [String] = [],
        note: String? = nil,
        tags: [String] = [],
        learningStatus: LearningStatus = .new,
        reviewCount: Int = 0,
        correctCount: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.collectionId = collectionId
        self.japanese = japanese
        self.english = english
        self.candidates = candidates
        self.note = note
        self.tags = tags
        self.learningStatus = learningStatus
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.createdAt = createdAt
    }
}

enum LearningStatus: String, Codable, CaseIterable {
    case new
    case notSure
    case reviewing
    case mastered

    var displayName: String {
        switch self {
        case .new:
            return "未学習"
        case .notSure:
            return "自信なし"
        case .reviewing:
            return "復習中"
        case .mastered:
            return "覚えた"
        }
    }
}
