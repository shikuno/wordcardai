import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Foundation Models を使った生成AIベースの翻訳サービス
// ※ここでは FoundationModels の LanguageModelSession API を想定した実装にしています。
class FoundationModelsTranslationService: TranslationServiceProtocol {
    
    func generateCandidates(from japanese: String, count: Int) async throws -> [String] {
        let trimmed = japanese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.emptyInput
        }
        
        // --- プロンプト組み立て ---
        let prompt = """
        以下の日本語文を、自然な英語文に翻訳してください。
        必ず 3 通りの異なる英語訳を出力してください。

        出力例（この形式を厳守してください）:
        I’m on my way.
        I’m coming now.
        I’ll be there soon.

        出力形式のルール:
        - 英語の文のみを書く
        - 1 行につき 1 文だけ書く
        - ちょうど 3 行だけ出力する
        - 行頭に番号や記号（1.、-、• など）は絶対に書かない
        - 説明文やコメント、日本語は書かない
        - 前後に余計な文字やコメントを書かない
        - 改行は候補の区切りとしてのみ使う

        日本語: \(trimmed)
        """
        
        print("\n===== FoundationModelsTranslationService =====")
        print("📝 Prompt to LLM:\n\(prompt)")
        
        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            do {
                let instructions = "You are a professional Japanese to English translator. Always respond in English only."
                let session = LanguageModelSession(instructions: instructions)
                
                let response = try await session.respond(to: prompt)

                // respond(to:) は iOS 26+ では String を直接返す
                let contentText: String
                if let str = response as? String {
                    contentText = str
                } else {
                    let raw = String(describing: response)
                    if let range = raw.range(of: #"rawContent: \".*?\""#, options: [.regularExpression]) {
                        let segment = String(raw[range])
                        let prefix = "rawContent: \""
                        if segment.hasPrefix(prefix), segment.hasSuffix("\"") {
                            let startIdx = segment.index(segment.startIndex, offsetBy: prefix.count)
                            let endIdx = segment.index(before: segment.endIndex)
                            contentText = String(segment[startIdx..<endIdx])
                        } else {
                            contentText = raw
                        }
                    } else {
                        contentText = raw
                    }
                }

                print("🧾 Extracted contentText:\n\(contentText)")

                // --- contentText から候補を抽出 ---
                let normalized = contentText.replacingOccurrences(of: "\\n", with: "\n")
                
                // 2) 改行で分割（すでに "1. ..." 形式で行ごとになっていることを期待）
                var lines = normalized
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // 3) もし改行が全く無く "1. Hello 2. Hi 3. Greetings" のように連結されている場合、
                //    番号パターンで分割を試みる
                if lines.count == 1 {
                    let single = lines[0]
                    // "1." "2." "3." を目印に分割
                    let pattern = "(?=[0-9]+\\.)" // "1.", "2." の前の位置で区切る
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let ns = single as NSString
                        let ranges = regex.matches(in: single, options: [], range: NSRange(location: 0, length: ns.length)).map { $0.range.location }
                        if !ranges.isEmpty {
                            var parts: [String] = []
                            for (idx, start) in ranges.enumerated() {
                                let end = (idx + 1 < ranges.count) ? ranges[idx + 1] : ns.length
                                let range = NSRange(location: start, length: end - start)
                                let chunk = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !chunk.isEmpty {
                                    parts.append(chunk)
                                }
                            }
                            if !parts.isEmpty {
                                lines = parts
                            }
                        }
                    }
                }
                
                // 4) 先頭の番号や箇条書き記号を削除
                lines = lines.map { line in
                    var s = line
                    // 例: "1. text", "1) text", "- text", "• text"
                    let patterns = ["^[0-9]+[\\).]*\\s*", "^[\\-•]\\s*"]
                    for pattern in patterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                            let range = NSRange(location: 0, length: (s as NSString).length)
                            s = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
                        }
                    }
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // 5) 英文らしさでフィルタリング
                lines = lines.filter { Self.isLikelyEnglishSentence($0) }
                
                // 6) 重複除去
                var candidates = Array(NSOrderedSet(array: lines)) as? [String] ?? lines
                
                // 7) 念のため候補内部の改行と "\n" をスペースに正規化し、1候補=1行にしておく
                candidates = candidates.map { candidate in
                    candidate
                        .replacingOccurrences(of: "\\n", with: " ")
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                print("🔎 Filtered candidates before padding: \(candidates)")
                
                if candidates.isEmpty {
                    throw TranslationError.processingError
                }
                
                // 8) 必要な数だけ用意（足りなければ先頭を複製）
                while candidates.count < count {
                    if let first = candidates.first {
                        candidates.append(first)
                    } else {
                        break
                    }
                }
                let result = Array(candidates.prefix(count))
                print("✅ Final candidates (\(result.count)):\n\(result.joined(separator: "\n"))")
                print("===== End FoundationModelsTranslationService =====\n")
                return result
            } catch {
                print("❌ Foundation Models LLM error: \(error)")
                // Foundation Models が使えない場合は簡易モックにフォールバック
                let fallback = Self.mockCandidates(for: trimmed, count: count)
                print("🟡 Using mock candidates instead:\n\(fallback.joined(separator: "\n"))")
                print("===== End FoundationModelsTranslationService (mock) =====\n")
                return fallback
            }
        }
        #endif
        
        // FoundationModels フレームワークを利用できない場合
        print("❌ Foundation Models framework is not available on this platform")
        let fallback = Self.mockCandidates(for: trimmed, count: count)
        print("🟡 Using mock candidates instead:\n\(fallback.joined(separator: "\n"))")
        print("===== End FoundationModelsTranslationService (mock) =====\n")
        return fallback
    }
    
    // 簡易判定: 英文っぽいかどうか
    private static func isLikelyEnglishSentence(_ text: String) -> Bool {
        if text.isEmpty { return false }
        
        // ひらがな・カタカナ・漢字が多い行は除外
        let japaneseCharSet = CharacterSet(charactersIn: "ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろわをん一-龠々〆ヵヶァ-ヴー")
        let jpCount = text.unicodeScalars.filter { japaneseCharSet.contains($0) }.count
        let total = text.unicodeScalars.count
        if total > 0 && Double(jpCount) / Double(total) > 0.3 {
            return false
        }
        
        // 英字を含まない行は除外
        let letterSet = CharacterSet.letters
        if !text.unicodeScalars.contains(where: { letterSet.contains($0) }) {
            return false
        }
        
        // 長さフィルタ
        if text.count < 3 || text.count > 200 {
            return false
        }
        
        // 明らかなメタ行を除外
        let bannedKeywords = ["Response<", "userPrompt", "assistant:", "system:"]
        if bannedKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return false
        }
        
        return true
    }
    
    // Foundation Models が使えない場合の簡易モック候補
    private static func mockCandidates(for japanese: String, count: Int) -> [String] {
        let base = "Please help me."
        let variations = [
            base,
            "I would appreciate your help.",
            "Could you please help me?"
        ]
        var result: [String] = []
        for i in 0..<max(count, 1) {
            result.append(variations[i % variations.count])
        }
        return result
    }
}
