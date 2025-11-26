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
}
