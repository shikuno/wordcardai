//
//  AppSettings.swift
//  WordCardAI
//
//  Created by YuyaFuruichi on 2025/11/23.
//

import Foundation

struct AppSettings: Codable {
    var candidateCount: Int // 1-5, default 3

    init(candidateCount: Int = 3) {
        self.candidateCount = min(max(candidateCount, 1), 5)
    }
}
