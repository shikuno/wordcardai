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

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: detectLanguageCode(for: trimmed))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    func stop() {
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
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {}
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {}
}

private extension String {
    var containsKanaOrKanji: Bool {
        unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) ||
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
}
