import Foundation

class OpenAITranslationService: TranslationServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateCandidates(from japanese: String, count: Int) async throws -> [String] {
        guard !japanese.isEmpty else {
            throw TranslationError.emptyInput
        }
        
        // OpenAI API リクエストの構築
        let prompt = """
        Translate the following Japanese phrase to natural English. 
        Provide \(count) different variations (formal, casual, common usage).
        Only respond with the English translations, one per line.
        
        Japanese: \(japanese)
        """
        
        let messages = [
            ["role": "system", "content": "You are a professional Japanese to English translator."],
            ["role": "user", "content": prompt]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 200
        ]
        
        // API リクエスト
        guard let url = URL(string: baseURL) else {
            throw TranslationError.processingError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.networkError
        }
        
        // レスポンスのパース
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationError.processingError
        }
        
        // 改行で分割して候補を取得
        let candidates = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(count)
        
        return Array(candidates)
    }
}
