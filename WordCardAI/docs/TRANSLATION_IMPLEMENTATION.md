# オンデバイス翻訳の実装について

## 概要
WordCardAI アプリに iOS のオンデバイス翻訳機能を統合しました。現在は MockTranslationService をベースに動作しますが、将来的に Apple の Translation API が公開された際に簡単に移行できる設計になっています。

## 現在の実装状況

### 1. MockTranslationService（現在使用中）
- **ファイル**: `Services/Translation/MockTranslationService.swift`
- **特徴**:
  - 固定の辞書データを使用
  - 完全にオフラインで動作
  - インターネット接続不要
  - プライバシー保護（データは端末内のみ）

### 2. AppleTranslationService（準備中）
- **ファイル**: `Services/Translation/AppleTranslationService.swift`
- **状態**: iOS 18 の Translation API の正式な公開を待機中
- **将来の計画**: Apple が Translation フレームワークを公開したら実装

### 3. NaturalLanguageTranslationService（準備中）
- **ファイル**: `Services/Translation/NaturalLanguageTranslationService.swift`
- **状態**: iOS 15+ の Natural Language API は現在翻訳機能が限定的
- **将来の計画**: API が拡張されたら実装

## 現在の翻訳機能

### MockTranslationService の辞書
以下の日本語フレーズに対して英語候補を提供：
- 挨拶: おはよう、こんにちは、こんばんは、さようなら
- 感謝: ありがとう、ありがとうございます
- 謝罪: すみません、ごめんなさい
- その他: よろしくお願いします、お疲れ様です、はい、いいえ、など

辞書にないフレーズの場合、汎用候補（`"{日本語} (translation)"` 形式）を返します。

## 使い方

### アプリ内での使用
1. カード作成画面で日本語を入力
2. 「候補を生成」ボタンをタップ
3. 辞書から英語候補を取得（0.5秒の遅延をシミュレート）
4. 候補から選択、または直接編集して保存

### 辞書の拡張方法
`MockTranslationService.swift` の `mockTranslations` 辞書に新しいエントリを追加：

```swift
private let mockTranslations: [String: [String]] = [
    "おはよう": ["Good morning", "Morning", "Hello"],
    // 新しいエントリを追加
    "新しいフレーズ": ["English 1", "English 2", "English 3"],
]
```

## Apple Translation API について

### なぜ現在使えないのか
- iOS 18 で Translation フレームワークが導入されましたが、開発者向け API の詳細はまだ限定的
- 公式ドキュメントやサンプルコードが不足している
- SwiftUI の Writing Tools は使えますが、プログラマティックな翻訳 API は制限されている

### 今後の展開
Apple が Translation API を正式公開したら：
1. `AppleTranslationService` を実装
2. `TranslationServiceFactory` で自動的に切り替え
3. 既存のコードは変更不要（プロトコルベースの設計）

## プライバシー
- すべてのデータはデバイス内に保存
- インターネット接続は不要
- ユーザーの入力データは外部に送信されない

## 代替案と拡張方法

### 1. OpenAI API の統合
オンライン翻訳が許容できる場合：
```swift
class OpenAITranslationService: TranslationServiceProtocol {
    func generateCandidates(from japanese: String, count: Int) async throws -> [String] {
        // OpenAI API を呼び出し
        // プロンプト: "Translate to English (provide {count} variations): {japanese}"
    }
}
```

### 2. Core ML カスタムモデル
独自の翻訳モデルを Core ML に変換して統合：
- Hugging Face から翻訳モデルをダウンロード
- `coremltools` で `.mlmodel` に変換
- Xcode プロジェクトに追加
- `LocalLLMService.swift` で推論を実行

### 3. ローカル LLM（Llama など）
- MLX フレームワークを使用
- GitHub の `mlx-swift` を統合
- デバイス上で小型 LLM を実行

## テスト方法

### 辞書登録フレーズのテスト
1. カード作成画面で「おはよう」を入力
2. 候補生成をタップ
3. "Good morning", "Morning", "Hello" が表示されることを確認

### 未登録フレーズのテスト
1. カード作成画面で「今日はいい天気ですね」を入力
2. 候補生成をタップ
3. 汎用候補が表示されることを確認

## トラブルシューティング

### 候補が表示されない
- Console ログを確認（"Translation failed:" メッセージ）
- 日本語入力が空でないか確認
- MockTranslationService の辞書に該当フレーズがあるか確認

### カスタマイズしたい
- `MockTranslationService.swift` の辞書を編集
- より多くのフレーズを追加
- 候補の順序や内容を変更

## 参考情報
- [Translation Framework - Apple Developer](https://developer.apple.com/documentation/translation)（iOS 18+、詳細は今後公開予定）
- [Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)
- [Core ML](https://developer.apple.com/documentation/coreml)
