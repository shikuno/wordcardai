import Foundation

class OpenAITranslationService: TranslationServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Step 1: 翻訳（1件）

    func translateOnce(text: String, targetLanguage: String) async throws -> String {
        guard !text.isEmpty else { throw TranslationError.emptyInput }
        let langName = Locale.current.localizedString(forLanguageCode: targetLanguage) ?? targetLanguage
        let prompt = "Translate the following text into \(langName). Write only the translation.\nText: \(text)"
        let results = try await callAPI(prompt: prompt, count: 1)
        guard let first = results.first else { throw TranslationError.processingError }
        return first
    }

    // MARK: - Step 2: 自然な表現を N 件生成

    func generateNaturalExpressions(from translated: String, count: Int) async throws -> [String] {
        guard !translated.isEmpty else { throw TranslationError.emptyInput }
        let prompt = """
        Give me exactly \(count) natural, native-sounding expressions or paraphrases for: \(translated)
        Write only the \(count) expressions, one per line, no numbering.
        """
        return try await callAPI(prompt: prompt, count: count)
    }

    // MARK: - Private

    private func callAPI(prompt: String, count: Int) async throws -> [String] {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a professional translator and native English speaker."],
            ["role": "user", "content": prompt]
        ]
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 300
        ]
        guard let url = URL(string: baseURL) else { throw TranslationError.processingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TranslationError.networkError
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationError.processingError
        }
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(lines.prefix(count))
    }
}
