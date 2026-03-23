//
//  AppSettings.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

struct AppSettings: Codable {
    var candidateCount: Int
    var playbackRate: Double
    var playbackSpeechTargetRawValue: String
    var playbackAutoAdvanceDelay: Double
    var playbackFrontToBackDelay: Double
    var hasSeenCardFlipHint: Bool
    /// 表面の言語コード（例: "ja", "en"）
    var frontLanguage: String
    /// 裏面の言語コード（例: "en", "ja"）
    var backLanguage: String

    init(
        candidateCount: Int = 3,
        playbackRate: Double = 1.0,
        playbackSpeechTargetRawValue: String = "frontOnly",
        playbackAutoAdvanceDelay: Double = 2.0,
        playbackFrontToBackDelay: Double = 1.0,
        hasSeenCardFlipHint: Bool = false,
        frontLanguage: String = "ja",
        backLanguage: String = "en"
    ) {
        self.candidateCount = min(max(candidateCount, 1), 5)
        self.playbackRate = min(max(playbackRate, 0.25), 2.0)
        self.playbackSpeechTargetRawValue = playbackSpeechTargetRawValue
        self.playbackAutoAdvanceDelay = min(max(playbackAutoAdvanceDelay, 0), 10)
        self.playbackFrontToBackDelay = min(max(playbackFrontToBackDelay, 0), 10)
        self.hasSeenCardFlipHint = hasSeenCardFlipHint
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
    }
}
