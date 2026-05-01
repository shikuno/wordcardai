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
    /// アップデート通知を最後に表示したバージョン
    var lastNotifiedAppVersion: String

    init(
        candidateCount: Int = 3,
        playbackRate: Double = 1.0,
        playbackSpeechTargetRawValue: String = "frontOnly",
        playbackAutoAdvanceDelay: Double = 2.0,
        playbackFrontToBackDelay: Double = 1.0,
        hasSeenCardFlipHint: Bool = false,
        frontLanguage: String = "ja",
        backLanguage: String = "en",
        lastNotifiedAppVersion: String = ""
    ) {
        self.candidateCount = min(max(candidateCount, 1), 5)
        self.playbackRate = min(max(playbackRate, 0.25), 2.0)
        self.playbackSpeechTargetRawValue = playbackSpeechTargetRawValue
        self.playbackAutoAdvanceDelay = min(max(playbackAutoAdvanceDelay, 0), 10)
        self.playbackFrontToBackDelay = min(max(playbackFrontToBackDelay, 0), 10)
        self.hasSeenCardFlipHint = hasSeenCardFlipHint
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
        self.lastNotifiedAppVersion = lastNotifiedAppVersion
    }

    private enum CodingKeys: String, CodingKey {
        case candidateCount
        case playbackRate
        case playbackSpeechTargetRawValue
        case playbackAutoAdvanceDelay
        case playbackFrontToBackDelay
        case hasSeenCardFlipHint
        case frontLanguage
        case backLanguage
        case lastNotifiedAppVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            candidateCount: try container.decodeIfPresent(Int.self, forKey: .candidateCount) ?? 3,
            playbackRate: try container.decodeIfPresent(Double.self, forKey: .playbackRate) ?? 1.0,
            playbackSpeechTargetRawValue: try container.decodeIfPresent(String.self, forKey: .playbackSpeechTargetRawValue) ?? "frontOnly",
            playbackAutoAdvanceDelay: try container.decodeIfPresent(Double.self, forKey: .playbackAutoAdvanceDelay) ?? 2.0,
            playbackFrontToBackDelay: try container.decodeIfPresent(Double.self, forKey: .playbackFrontToBackDelay) ?? 1.0,
            hasSeenCardFlipHint: try container.decodeIfPresent(Bool.self, forKey: .hasSeenCardFlipHint) ?? false,
            frontLanguage: try container.decodeIfPresent(String.self, forKey: .frontLanguage) ?? "ja",
            backLanguage: try container.decodeIfPresent(String.self, forKey: .backLanguage) ?? "en",
            lastNotifiedAppVersion: try container.decodeIfPresent(String.self, forKey: .lastNotifiedAppVersion) ?? ""
        )
    }
}
