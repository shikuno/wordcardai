//
//  SpeechService.swift
//  WordCardAI
//
//  Created by Copilot on 2026/03/17.
//

import Foundation
import AVFoundation
import NaturalLanguage

@MainActor
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        speak(text, rate: AVSpeechUtteranceDefaultSpeechRate, onFinish: nil)
    }

    func speak(_ text: String, rate: Float, onFinish: (() -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onFinish?()
            return
        }

        self.onFinish = onFinish

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: detectLanguageCode(for: trimmed))
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
        onFinish = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage {
            switch language {
            case .japanese:
                return "ja-JP"
            case .english:
                return "en-US"
            default:
                break
            }
        }

        if text.containsKanaOrKanji {
            return "ja-JP"
        }
        return "en-US"
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {}
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let callback = self.onFinish
            self.onFinish = nil
            callback?()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onFinish = nil
        }
    }
}

private extension String {
    var containsKanaOrKanji: Bool {
        unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) ||
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
}
