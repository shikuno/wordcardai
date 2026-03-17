//
//  SettingsService.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation
import SwiftUI
import Combine

class SettingsService: ObservableObject {
    @Published var settings: AppSettings
    
    private let storage: StorageProtocol
    
    init(storage: StorageProtocol) {
        self.storage = storage
        
        // Load settings from storage or use defaults
        if let loadedSettings = try? storage.loadSettings() {
            self.settings = loadedSettings
        } else {
            self.settings = AppSettings()
        }
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        try? storage.saveSettings(newSettings)
    }
    
    func updateCandidateCount(_ count: Int) {
        var newSettings = settings
        newSettings.candidateCount = min(max(count, 1), 5)
        updateSettings(newSettings)
    }
    
    func updatePlaybackRate(_ rate: Double) {
        var newSettings = settings
        newSettings.playbackRate = min(max(rate, 0.25), 2.0)
        updateSettings(newSettings)
    }

    func updatePlaybackFrontToBackDelay(_ delay: Double) {
        var newSettings = settings
        newSettings.playbackFrontToBackDelay = min(max(delay, 0), 10)
        updateSettings(newSettings)
    }

    func updatePlaybackSpeechTarget(_ rawValue: String) {
        var newSettings = settings
        newSettings.playbackSpeechTargetRawValue = rawValue
        updateSettings(newSettings)
    }

    func updatePlaybackAutoAdvanceDelay(_ delay: Double) {
        var newSettings = settings
        newSettings.playbackAutoAdvanceDelay = min(max(delay, 0), 10)
        updateSettings(newSettings)
    }

    func updateHasSeenCardFlipHint(_ hasSeen: Bool) {
        var newSettings = settings
        newSettings.hasSeenCardFlipHint = hasSeen
        updateSettings(newSettings)
    }
}
