import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

class FoundationModelsTranslationService: TranslationServiceProtocol {

    /// デバッグ用：最後の入力・プロンプト・生出力を保持
    static var lastRawInput: String = "(まだ生成していません)"
    static var lastPrompt: String = "(まだ生成していません)"
    static var lastRawOutput: String = "(まだ生成していません)"
    
    func generateCandidates(from japanese: String, count: Int) async throws -> [String] {
        // 改行・タブ・連続スペースをすべて半角スペース1つに正規化して1行にする
        let trimmed = japanese
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !trimmed.isEmpty else {
            throw TranslationError.emptyInput
        }
        
        let prompt = """
        Translate the following Japanese into exactly \(count) English sentences.
        Write only the \(count) sentences, one per line, nothing else.
        Japanese: \(trimmed)
        """

        // デバッグ用：入力とプロンプトを保存
        FoundationModelsTranslationService.lastRawInput = trimmed
        FoundationModelsTranslationService.lastPrompt = prompt
        
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            do {
                let session = LanguageModelSession(
                    instructions: "You are a professional translator. Output only the requested sentences, one per line, no numbering, no explanation."
                )
                let response = try await session.respond(to: prompt)
                let text = response.content
                // デバッグ用：生出力をそのまま保存（加工なし）
                FoundationModelsTranslationService.lastRawOutput = text
                
                // 改行で分割してそのまま返す
                let lines = text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // 番号「1. 」「1) 」だけ除去（最小限）
                let cleaned = lines.map { line -> String in
                    var s = line
                    if let r = try? NSRegularExpression(pattern: "^\\d+[.)\\s]+") {
                        s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
                    }
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
                
                guard !cleaned.isEmpty else { throw TranslationError.processingError }
                
                // 足りなければ末尾を繰り返す、多ければ切る
                var result = cleaned
                while result.count < count { result.append(result.last ?? "") }
                return Array(result.prefix(count))
                
            } catch {
                throw error
            }
        }
        #endif
        throw TranslationError.processingError
    }
    
    // 英文っぽいかどうかの判定（最小限）
    private static func isLikelyEnglishSentence(_ text: String) -> Bool {
        guard !text.isEmpty, text.count >= 2 else { return false }
        let jpChars = CharacterSet(charactersIn: "ぁ-んァ-ヴ一-龠々〆")
        let jpCount = text.unicodeScalars.filter { jpChars.contains($0) }.count
        return jpCount == 0
    }
}
