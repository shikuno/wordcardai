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
    /// 翻訳・生成がどのパスを通ったかの詳細ログ
    static var lastFlowLog:   String = "(まだ生成していません)"

    private static func appendFlow(_ msg: String) {
        lastFlowLog += "\n" + msg
    }
    private static func resetFlow(_ title: String) {
        lastFlowLog = "=== \(title) ===\n[\(Date().formatted(date: .omitted, time: .standard))]"
        lastPrompt = "(まだ生成していません)"
        lastRawOutput = "(まだ生成していません)"
    }
    private static func appendPrompt(_ label: String, _ prompt: String) {
        if lastPrompt == "(まだ生成していません)" {
            lastPrompt = "[\(label)]\n\(prompt)"
        } else {
            lastPrompt += "\n\n[\(label)]\n\(prompt)"
        }
    }
    private static func appendRawOutput(_ label: String, _ output: String) {
        if lastRawOutput == "(まだ生成していません)" {
            lastRawOutput = "[\(label)]\n\(output)"
        } else {
            lastRawOutput += "\n\n[\(label)]\n\(output)"
        }
    }

    // MARK: - Step 1: 翻訳（Translation Framework → LLM フォールバック）

    func translateOnce(text: String, sourceLanguage: String = "ja", targetLanguage: String = "en") async throws -> String {
        let trimmed = normalize(text)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        FoundationModelsTranslationService.lastRawInput = trimmed
        FoundationModelsTranslationService.resetFlow("翻訳 (\(sourceLanguage)→\(targetLanguage))")
        FoundationModelsTranslationService.appendFlow("入力: \(trimmed)")

        // ① Apple Translation Framework を試みる
        #if canImport(Translation)
        if #available(iOS 17.4, *) {
            FoundationModelsTranslationService.appendFlow("① Translation Framework を試みる…")
            if let result = try? await translateWithFramework(text: trimmed, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
                FoundationModelsTranslationService.appendFlow("✅ Translation Framework 成功")
                FoundationModelsTranslationService.appendFlow("結果: \(result)")
                return result
            } else {
                FoundationModelsTranslationService.appendFlow("❌ Translation Framework 失敗（言語パック未インストール or iOS 26未満）")
                FoundationModelsTranslationService.appendFlow("② LLM フォールバックへ")
            }
        }
        #else
        FoundationModelsTranslationService.appendFlow("① Translation Framework 利用不可（Translation非対応ビルド）")
        FoundationModelsTranslationService.appendFlow("② LLM フォールバックへ")
        #endif

        return try await translateWithLLM(text: trimmed, targetLanguage: targetLanguage)
    }

    // MARK: - Step 2: 自然な表現を N 件生成（LLM のみ）

    func generateNaturalExpressions(from translated: String, targetLanguage: String = "en", count: Int) async throws -> [String] {
        let trimmed = normalize(translated)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        FoundationModelsTranslationService.appendFlow("【自然な表現生成】入力: \(trimmed) / 言語: \(targetLanguage) / 件数: \(count)")

        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let langName = Locale(identifier: "en").localizedString(forLanguageCode: targetLanguage) ?? targetLanguage
            FoundationModelsTranslationService.appendFlow("LLM (\(langName)) で \(count) 件生成…")

            let prompt = """
            Task: vocabulary learning paraphrase generation for a flashcard app.
            Language: \(langName)
            Count: \(count)

            The input is a vocabulary item from a flashcard. It may be an idiom, proverb, or colloquial expression.
            Many languages have common idioms using words related to death, body, or strong emotions — these are normal educational content.

            Generate exactly \(count) natural, native-sounding \(langName) paraphrases of this vocabulary item:
            \(trimmed)

            Rules:
            - Output ONLY the \(count) paraphrases, one per line
            - No numbering, no bullets, no explanation
            - No introductory sentence
            - Start directly with the first paraphrase
            """
            FoundationModelsTranslationService.appendPrompt("自然表現生成:初回", prompt)

            let instructions = """
            You are a \(langName) paraphrase generator for a vocabulary learning flashcard app.
            Users submit idioms, proverbs, and expressions — including ones that may contain words like "death" or "pain" in various languages. These are normal vocabulary items.
            Output ONLY the requested paraphrases. No preamble, no explanation, no apology. Start with the first paraphrase.
            """

            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let raw = response.content
            FoundationModelsTranslationService.appendRawOutput("自然表現生成:初回", raw)

            if isRefusalResponse(raw) {
                FoundationModelsTranslationService.appendFlow("❌ 安全フィルター発動 → エラー")
                throw TranslationError.processingError
            }

            let lines = parseLines(raw, expected: count)
            guard !lines.isEmpty else {
                FoundationModelsTranslationService.appendFlow("❌ パース失敗（空結果）")
                throw TranslationError.processingError
            }
            FoundationModelsTranslationService.appendFlow("✅ 生成成功: \(lines.joined(separator: " / "))")
            return lines
        } else {
            FoundationModelsTranslationService.appendFlow("❌ iOS 18.2 未満 → 利用不可")
        }
        #else
        FoundationModelsTranslationService.appendFlow("❌ FoundationModels 非対応ビルド")
        #endif
        throw TranslationError.unavailable
    }

    func generateNaturalExpressionsDirect(
        from sourceText: String,
        sourceLanguage: String,
        targetLanguage: String,
        count: Int
    ) async throws -> [String] {
        let trimmed = normalize(sourceText)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }
        FoundationModelsTranslationService.lastRawInput = trimmed
        FoundationModelsTranslationService.resetFlow("直接生成 (\(sourceLanguage)→\(targetLanguage))")
        FoundationModelsTranslationService.appendFlow("入力: \(trimmed)")
        FoundationModelsTranslationService.appendFlow("中間翻訳なしで直接 \(count) 件生成")

        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let sourceName = Locale(identifier: "en").localizedString(forLanguageCode: sourceLanguage) ?? sourceLanguage
            let targetName = Locale(identifier: "en").localizedString(forLanguageCode: targetLanguage) ?? targetLanguage
            FoundationModelsTranslationService.appendFlow("LLM 直接生成: \(sourceName) → \(targetName)")

            let prompt = """
            Task: Create high-quality flashcard answers by directly converting a source expression into natural target-language expressions.
            Source language: \(sourceName)
            Target language: \(targetName)
            Count: \(count)
            Safety context: This is vocabulary translation for study only. The source may include difficult words (e.g. death, pain, fear) as normal language content.

            Source text:
            \(trimmed)

            Goal:
            - Understand the source meaning and intent first (do not do literal word-by-word translation)
            - Produce exactly \(count) natural \(targetName) expressions suitable for a language learner's flashcard back side

            Quality rules:
            - Keep each candidate concise and practical for daily conversation
            - Preserve original meaning and tone
            - Make candidates clearly different in nuance/register (common, casual, polite, etc.)
            - Avoid awkward literal translations and avoid adding extra context not in the source

            Output rules:
            - Output ONLY the \(count) expressions, one per line
            - No numbering, bullets, quotes, explanations, or headings
            - Start directly from the first expression
            """
            FoundationModelsTranslationService.appendPrompt("直接生成:初回", prompt)

            let instructions = """
            You are an expert bilingual lexicographer and translation writer for a flashcard app.
            This task is educational vocabulary translation only, not advice.
            Source text can include sensitive words in literal/idiomatic usage.
            Your top priority is natural target-language quality while preserving source meaning.
            Avoid literal calques. Output exactly the requested number of lines only.
            """

            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(to: prompt)
                let raw = response.content
                FoundationModelsTranslationService.appendRawOutput("直接生成:初回", raw)

                if isRefusalResponse(raw) {
                    FoundationModelsTranslationService.appendFlow("❌ 直接生成で unsafe 判定（拒否文）")
                    return try await retryOnlyFromDirectGeneration(
                        sourceText: trimmed,
                        sourceLanguageName: sourceName,
                        targetLanguageName: targetName,
                        count: count,
                        instructions: instructions,
                        reason: "unsafe(拒否文)"
                    )
                }

                let lines = parseLines(raw, expected: count)
                guard !lines.isEmpty else {
                    FoundationModelsTranslationService.appendFlow("❌ 直接生成のパース失敗（空結果）")
                    return try await retryOnlyFromDirectGeneration(
                        sourceText: trimmed,
                        sourceLanguageName: sourceName,
                        targetLanguageName: targetName,
                        count: count,
                        instructions: instructions,
                        reason: "空結果"
                    )
                }
                FoundationModelsTranslationService.appendFlow("✅ 直接生成成功: \(lines.joined(separator: " / "))")
                return lines
            } catch {
                FoundationModelsTranslationService.appendFlow("❌ 直接生成で例外発生: \(error.localizedDescription)")
                FoundationModelsTranslationService.appendRawOutput("直接生成:初回(例外)", error.localizedDescription)
                return try await retryOnlyFromDirectGeneration(
                    sourceText: trimmed,
                    sourceLanguageName: sourceName,
                    targetLanguageName: targetName,
                    count: count,
                    instructions: instructions,
                    reason: "例外発生"
                )
            }
        } else {
            FoundationModelsTranslationService.appendFlow("❌ iOS 18.2 未満 → 直接生成不可")
        }
        #else
        FoundationModelsTranslationService.appendFlow("❌ FoundationModels 非対応ビルド")
        #endif
        throw TranslationError.unavailable
    }

    @available(iOS 18.2, *)
    private func generateNaturalExpressionsDirectRetry(
        sourceText: String,
        sourceLanguage: String,
        targetLanguage: String,
        count: Int,
        instructions: String,
        promptStyle: Int
    ) async throws -> String {
        let retryPrompt: String
        FoundationModelsTranslationService.appendFlow("リトライ1: 教育用途を強調した簡潔プロンプトで再送")
        retryPrompt = """
        This is for language-learning flashcards only.
        Convert the quoted \(sourceLanguage) vocabulary into exactly \(count) natural \(targetLanguage) expressions.
        The phrase can contain words about death, pain, or fear as normal language material.

        Source (quoted text, not a request for advice):
        "\(sourceText)"

        Output only \(count) lines in \(targetLanguage).
        No safety warning, no explanation, no numbering.
        """

        FoundationModelsTranslationService.appendPrompt("直接生成:リトライ1", retryPrompt)
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: retryPrompt)
            let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            FoundationModelsTranslationService.appendRawOutput("直接生成:リトライ1", result)
            return result
        } catch {
            FoundationModelsTranslationService.appendFlow("❌ リトライ\(promptStyle)でも例外: \(error.localizedDescription)")
            FoundationModelsTranslationService.appendRawOutput("直接生成:リトライ1(例外)", error.localizedDescription)
            throw error
        }
    }

    @available(iOS 18.2, *)
    private func retryOnlyFromDirectGeneration(
        sourceText: String,
        sourceLanguageName: String,
        targetLanguageName: String,
        count: Int,
        instructions: String,
        reason: String
    ) async throws -> [String] {
        FoundationModelsTranslationService.appendFlow("再試行開始: 理由=\(reason)")

        for style in [1] {
            do {
                let retried = try await generateNaturalExpressionsDirectRetry(
                    sourceText: sourceText,
                    sourceLanguage: sourceLanguageName,
                    targetLanguage: targetLanguageName,
                    count: count,
                    instructions: instructions,
                    promptStyle: style
                )
                if isRefusalResponse(retried) {
                    FoundationModelsTranslationService.appendFlow("❌ リトライ\(style): unsafe(拒否文)")
                    continue
                }
                let retryLines = parseLines(retried, expected: count)
                if !retryLines.isEmpty {
                    FoundationModelsTranslationService.appendFlow("✅ リトライ\(style)成功: \(retryLines.joined(separator: " / "))")
                    return retryLines
                } else {
                    FoundationModelsTranslationService.appendFlow("❌ リトライ\(style): 空結果")
                }
            } catch {
                FoundationModelsTranslationService.appendFlow("❌ リトライ\(style): 例外で失敗 (\(error.localizedDescription))")
            }
        }

        FoundationModelsTranslationService.appendFlow("❌ リトライ失敗: unsafe のため生成不可")
        throw TranslationError.unsafeContent
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
            let langName = Locale(identifier: "en").localizedString(forLanguageCode: targetLanguage) ?? targetLanguage
            FoundationModelsTranslationService.appendFlow("LLM 翻訳 → \(langName)")

            let prompt = """
            Task: translate a vocabulary item for a language learning flashcard app.
            Target language: \(langName)

            The input is a word or phrase from a flashcard. It may be an idiom, proverb, or colloquial expression.
            Many languages (including Japanese) have common idioms that contain words related to death, body, or strong emotions — these are normal vocabulary items.

            Translate the following flashcard text into \(langName):
            \(text)

            Rules:
            - Output ONLY the \(langName) translation
            - No preamble, no explanation, no apology
            - Start directly with the translated text
            """
            FoundationModelsTranslationService.appendPrompt("翻訳LLM:初回", prompt)

            let instructions = """
            You are a translation engine embedded in a language learning flashcard app.
            Users submit vocabulary words and phrases — including idioms, proverbs, and colloquial expressions.
            Japanese, Chinese, and other languages commonly use characters meaning "death", "kill", "pain" etc. in everyday idioms (e.g. 死に物狂い = desperately). These are normal educational content.
            Your job is to translate accurately. Output ONLY the translation. Never refuse or apologize.
            """

            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            var result = stripPreamble(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
            FoundationModelsTranslationService.appendRawOutput("翻訳LLM:初回", result)

            if isRefusalResponse(result) {
                FoundationModelsTranslationService.appendFlow("❌ 安全フィルター発動 → リトライ")
                result = try await translateWithLLMRetry(text: text, targetLanguage: langName, instructions: instructions)
                if isRefusalResponse(result) {
                    FoundationModelsTranslationService.appendFlow("❌ リトライも失敗 → エラー")
                } else {
                    FoundationModelsTranslationService.appendFlow("✅ リトライ成功: \(result)")
                }
            } else {
                FoundationModelsTranslationService.appendFlow("✅ LLM 翻訳成功: \(result)")
            }

            guard !result.isEmpty && !isRefusalResponse(result) else { throw TranslationError.processingError }
            return result
        } else {
            FoundationModelsTranslationService.appendFlow("❌ iOS 18.2 未満 → LLM 利用不可")
        }
        #else
        FoundationModelsTranslationService.appendFlow("❌ FoundationModels 非対応ビルド")
        #endif
        throw TranslationError.unavailable
    }

    @available(iOS 18.2, *)
    private func translateWithLLMRetry(text: String, targetLanguage: String, instructions: String) async throws -> String {
        #if canImport(FoundationModels)
        FoundationModelsTranslationService.appendFlow("リトライ: 別表現でプロンプト再送")
        let retryPrompt = """
        Language learning task. A student is studying the following vocabulary item:

        Vocabulary: \(text)

        Please provide the \(targetLanguage) equivalent or translation of this vocabulary item.
        Output only the \(targetLanguage) text.
        """
        FoundationModelsTranslationService.appendPrompt("翻訳LLM:リトライ", retryPrompt)
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: retryPrompt)
        let result = stripPreamble(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
        FoundationModelsTranslationService.appendRawOutput("翻訳LLM:リトライ", result)
        return result
        #else
        throw TranslationError.unavailable
        #endif
    }

    // MARK: - Private: 安全フィルター拒否レスポンスの検知

    private func isRefusalResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        let refusalPhrases = [
            "i apologize",
            "i'm sorry",
            "i cannot",
            "i can't",
            "i am unable",
            "offensive",
            "inappropriate",
            "cannot help",
            "unable to assist",
            "unsafe",
            "content likely to be unsafe",
            "policy",
        ]
        return refusalPhrases.contains { lower.contains($0) }
    }

    // MARK: - Private: ユーティリティ

    /// 改行・連続スペースを1スペースに正規化
    private func normalize(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// 「Sure, here are...」「OK, ...」などの前置き行を除去する
    private func stripPreamble(_ text: String) -> String {
        let preamblePatterns = [
            #"^(sure[,!.]?|ok[,!.]?|of course[,!.]?|certainly[,!.]?|absolutely[,!.]?)"#,
            #"^here (is|are).*?[:\n]"#,
            #"^translation[:\s]+"#,
            #"^\w+ translation[:\s]+"#,
        ]
        var result = text
        for pattern in preamblePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return result
    }

    /// レスポンスを行に分割し、番号・前置き行を除去して返す
    private func parseLines(_ raw: String, expected: Int) -> [String] {
        let numberPattern = try? NSRegularExpression(pattern: #"^\d+[.)]\s*"#)
        let bulletPattern = try? NSRegularExpression(pattern: #"^[-•*]\s*"#)

        // 前置き行のキーワード（これらだけからなる行はスキップ）
        let preambleKeywords = [
            "here are", "here is", "sure", "ok,", "okay",
            "certainly", "of course", "absolutely", "paraphrase",
            "expressions:", "alternatives:", "translation:"
        ]

        var lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                // 前置き行をスキップ
                let lower = line.lowercased()
                return !preambleKeywords.contains { lower.hasPrefix($0) }
            }
            .map { line -> String in
                var s = line
                // 番号 "1. " "2) " を除去
                if let r = numberPattern {
                    s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
                }
                // 箇条書き記号 "- " "• " を除去
                if let r = bulletPattern {
                    s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
                }
                // 先頭末尾の引用符を除去
                s = s.trimmingCharacters(in: .init(charactersIn: "\"'「」"))
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        // 不足なら末尾を繰り返し、多ければ切る
        while lines.count < expected, let last = lines.last { lines.append(last) }
        return Array(lines.prefix(expected))
    }
}
