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
    var hasSeenCardFlipHint: Bool

    init(
        candidateCount: Int = 3,
        playbackRate: Double = 0.5,
        playbackSpeechTargetRawValue: String = "frontOnly",
        playbackAutoAdvanceDelay: Double = 0.8,
        hasSeenCardFlipHint: Bool = false
    ) {
        self.candidateCount = min(max(candidateCount, 1), 5)
        self.playbackRate = min(max(playbackRate, 0.3), 0.72)
        self.playbackSpeechTargetRawValue = playbackSpeechTargetRawValue
        self.playbackAutoAdvanceDelay = min(max(playbackAutoAdvanceDelay, 0), 10)
        self.hasSeenCardFlipHint = hasSeenCardFlipHint
    }
}
