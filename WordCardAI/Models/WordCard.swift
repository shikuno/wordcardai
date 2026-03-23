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
    /// 表面テキスト（旧: japanese）
    var front: String
    /// 裏面テキスト（旧: english）
    var back: String
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
        front: String,
        back: String,
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
        self.front = front
        self.back = back
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

    // MARK: - 後方互換性（旧 japanese/english を使っている既存データのデコード対応）

    enum CodingKeys: String, CodingKey {
        case id, collectionId, candidates, note, tags
        case learningStatus, reviewCount, correctCount
        case lastReviewedAt, nextReviewAt, createdAt
        case front, back
        // 旧フィールド名
        case japanese, english
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self, forKey: .id)
        collectionId   = try c.decode(UUID.self, forKey: .collectionId)
        // front: 新フィールド優先、なければ旧フィールド japanese を使う
        if let f = try? c.decode(String.self, forKey: .front) {
            front = f
        } else {
            front = try c.decode(String.self, forKey: .japanese)
        }
        // back: 新フィールド優先、なければ旧フィールド english を使う
        if let b = try? c.decode(String.self, forKey: .back) {
            back = b
        } else {
            back = try c.decode(String.self, forKey: .english)
        }
        candidates     = (try? c.decode([String].self, forKey: .candidates)) ?? []
        note           = try? c.decode(String.self, forKey: .note)
        tags           = (try? c.decode([String].self, forKey: .tags)) ?? []
        learningStatus = (try? c.decode(LearningStatus.self, forKey: .learningStatus)) ?? .new
        reviewCount    = (try? c.decode(Int.self, forKey: .reviewCount)) ?? 0
        correctCount   = (try? c.decode(Int.self, forKey: .correctCount)) ?? 0
        lastReviewedAt = try? c.decode(Date.self, forKey: .lastReviewedAt)
        nextReviewAt   = try? c.decode(Date.self, forKey: .nextReviewAt)
        createdAt      = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,             forKey: .id)
        try c.encode(collectionId,   forKey: .collectionId)
        try c.encode(front,          forKey: .front)
        try c.encode(back,           forKey: .back)
        try c.encode(candidates,     forKey: .candidates)
        try c.encodeIfPresent(note,  forKey: .note)
        try c.encode(tags,           forKey: .tags)
        try c.encode(learningStatus, forKey: .learningStatus)
        try c.encode(reviewCount,    forKey: .reviewCount)
        try c.encode(correctCount,   forKey: .correctCount)
        try c.encodeIfPresent(lastReviewedAt, forKey: .lastReviewedAt)
        try c.encodeIfPresent(nextReviewAt,   forKey: .nextReviewAt)
        try c.encode(createdAt,      forKey: .createdAt)
    }

    // MARK: - 後方互換 computed properties（他ファイルが japanese/english を参照している間の移行期用）

    var japanese: String {
        get { front }
        set { front = newValue }
    }

    var english: String {
        get { back }
        set { back = newValue }
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
