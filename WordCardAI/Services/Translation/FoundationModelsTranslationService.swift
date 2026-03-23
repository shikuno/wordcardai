import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Translation)
import Translation
#endif

class FoundationModelsTranslationService: TranslationServiceProtocol {

    // MARK: - デバッグ用ログ
    static var lastRawInput:  String = "(まだ生成していません)"
    static var lastPrompt:    String = "(まだ生成していません)"
    static var lastRawOutput: String = "(まだ生成していません)"

    // MARK: - Step 1: 翻訳（Translation Framework → LLM フォールバック）

    func translateOnce(text: String, sourceLanguage: String = "ja", targetLanguage: String = "en") async throws -> String {
        let trimmed = normalize(text)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        FoundationModelsTranslationService.lastRawInput = trimmed

        // ① Apple Translation Framework を試みる
        #if canImport(Translation)
        if #available(iOS 17.4, *) {
            if let result = try? await translateWithFramework(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
                return result
            }
        }
        #endif

        // ② フォールバック: LLM で翻訳
        return try await translateWithLLM(text: trimmed, targetLanguage: targetLanguage)
    }

    // MARK: - Step 2: 自然な表現を N 件生成（LLM のみ）

    func generateNaturalExpressions(from translated: String, targetLanguage: String = "en", count: Int) async throws -> [String] {
        let trimmed = normalize(translated)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let prompt = """
            Give me exactly \(count) natural, native-sounding expressions or paraphrases for the following phrase.
            Write only the \(count) expressions, one per line, no numbering, no explanation.
            Phrase: \(trimmed)
            """
            FoundationModelsTranslationService.lastPrompt = prompt

            let session = LanguageModelSession(
                instructions: "You are a native English speaker. Output only the requested expressions, one per line."
            )
            let response = try await session.respond(to: prompt)
            let raw = response.content
            FoundationModelsTranslationService.lastRawOutput = raw

            let lines = parseLines(raw, expected: count)
            guard !lines.isEmpty else { throw TranslationError.processingError }
            return lines
        }
        #endif
        throw TranslationError.unavailable
    }

    // MARK: - Private: Translation Framework

    #if canImport(Translation)
    @available(iOS 17.4, *)
    private func translateWithFramework(text: String, sourceLanguage: String, targetLanguage: String) async throws -> String? {
        do {
            let targetLocale = Locale.Language(identifier: targetLanguage)
            if #available(iOS 26.0, *) {
                let session = TranslationSession(
                    installedSource: Locale.Language(identifier: sourceLanguage),
                    target: targetLocale
                )
                let response = try await session.translate(text)
                return response.targetText
            }
            return nil
        } catch {
            return nil
        }
    }
    #endif

    // MARK: - Private: LLM 翻訳

    private func translateWithLLM(text: String, targetLanguage: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let langName = Locale.current.localizedString(forLanguageCode: targetLanguage) ?? targetLanguage
            let prompt = """
            Translate the following text into \(langName).
            Write only the translation, nothing else.
            Text: \(text)
            """
            FoundationModelsTranslationService.lastPrompt = prompt

            let session = LanguageModelSession(
                instructions: "You are a professional translator. Output only the translation."
            )
            let response = try await session.respond(to: prompt)
            let result = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            FoundationModelsTranslationService.lastRawOutput = result
            guard !result.isEmpty else { throw TranslationError.processingError }
            return result
        }
        #endif
        throw TranslationError.unavailable
    }

    // MARK: - Private: ユーティリティ

    /// 改行・連続スペースを1スペースに正規化
    private func normalize(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// レスポンスを行に分割し、番号記号を除去して返す
    private func parseLines(_ raw: String, expected: Int) -> [String] {
        let numberPattern = try? NSRegularExpression(pattern: #"^\d+[.)]\s*"#)
        var lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                var s = line
                if let r = numberPattern {
                    s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
                }
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        // 不足なら末尾を繰り返し、多ければ切る
        while lines.count < expected { lines.append(lines.last ?? "") }
        return Array(lines.prefix(expected))
    }
}
