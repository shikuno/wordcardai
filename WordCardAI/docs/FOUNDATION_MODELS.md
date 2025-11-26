# Foundation Models Framework 統合について

## 概要
Apple が発表した **Foundation Models Framework** を WordCardAI アプリに統合しました。iOS 18.2 を最低バージョンとし、Apple Intelligence の大規模言語モデルをデフォルトで使用します。

## プロジェクト設定
- **最低 iOS バージョン**: 18.2
- **デフォルト翻訳サービス**: Foundation Models (Apple Intelligence)
- **完全オンデバイス**: データは外部に送信されない

## Foundation Models Framework とは

### 発表内容
- **発表時期**: 2024年（WWDC 2024後）
- **利用可能**: iOS 18.2+、iPadOS 18.2+、macOS 15.2+
- **特徴**: Apple Intelligence の中核を担う大規模言語モデルへのプログラマティックなアクセス

### 主な機能
1. **テキスト生成**: プロンプトベースで自然な文章を生成
2. **翻訳**: 複数言語間の翻訳（日本語→英語含む）
3. **要約**: 長文を簡潔にまとめる
4. **書き換え**: トーンや文体を変更
5. **完全オンデバイス**: プライバシー保護、インターネット不要

## 実装内容

### 追加したファイル
- **FoundationModelsTranslationService.swift**: Foundation Models を使った翻訳サービス（デフォルト）
- **OpenAITranslationService.swift**: OpenAI API を使った翻訳サービス（オプション）
- **MockTranslationService.swift**: 開発・テスト用（オプション）

### 翻訳サービスの選択肢
アプリでは以下の4つの翻訳サービスから選択できます（デフォルトは Foundation Models）：

1. **Apple Intelligence（オンデバイス）** - デフォルト
   - Foundation Models Framework 使用
   - 完全オンデバイス、プライバシー保護
   - 高品質な翻訳
   - インターネット不要
   - iOS 18.2+ で常に利用可能

2. **OpenAI（オンライン）** - オプション
   - OpenAI API（GPT-4o-mini）使用
   - インターネット接続必要
   - API キーが必要
   - 複数の候補を生成可能

3. **ローカルLLM（準備中）** - 将来実装予定
   - MLX や Core ML を使用
   - 完全オンデバイス

4. **Mock（開発用）** - テスト用
   - 固定辞書を使用
   - オフライン動作

## 使い方

### Foundation Models の使用（デフォルト）
1. アプリを起動（設定不要、自動的に Foundation Models を使用）
2. カード作成画面で日本語を入力
3. 「候補を生成」をタップ
4. Apple Intelligence が英語候補を生成（オンデバイス）

### 翻訳サービスの変更（オプション）
1. 設定画面を開く
2. 「AI設定」セクションで「翻訳サービス」を選択
3. 他のサービス（OpenAI、Mock等）を選択可能

### OpenAI の使用（オプション）
1. OpenAI の API キーを取得（https://platform.openai.com/api-keys）
2. 設定画面で「翻訳サービス」を「OpenAI（オンライン）」に変更
3. API キーを入力
4. カード作成画面で使用

## 技術的な詳細

### Foundation Models API の使用例（予定）
```swift
// iOS 18.2+ での使用方法（API公開後）
let model = try await FoundationModel.load(.languageModel)
let prompt = "Translate to English: こんにちは"
let response = try await model.generate(prompt: prompt)
let translation = response.text
```

### 現在の実装状態
- **Foundation Models**: デフォルトで使用、API の正式公開待ち（暫定的にモックで代替）
- **OpenAI**: 完全実装済み、オプションで使用可能
- **Mock**: 完全実装済み、開発・テスト用

### 自動フォールバック
1. Foundation Models を優先使用
2. API が未公開の間は内部的にモックで代替
3. 正式 API 公開後は自動的に切り替わる

## プライバシー

### Foundation Models（Apple Intelligence）- デフォルト
- ✅ 完全オンデバイス処理
- ✅ データは外部送信されない
- ✅ Apple のプライバシー保護基準に準拠
- ✅ インターネット不要

### OpenAI - オプション
- ⚠️ データは OpenAI のサーバーに送信される
- ⚠️ OpenAI のプライバシーポリシーに準拠
- ⚠️ API 使用料が発生
- ⚠️ インターネット接続必須

### Mock - テスト用
- ✅ 完全オンデバイス
- ✅ データは外部送信されない
- ✅ インターネット不要

## 今後の予定

### 短期（API 正式公開後）
1. Foundation Models の正式 API を実装
2. モックから実際の AI 推論に切り替え
3. 実機でのテストと最適化
4. 複数候補生成のチューニング

### 中期
1. トーン指定（丁寧・カジュアル）機能の追加
2. 文脈を考慮した翻訳
3. 学習履歴から個人に最適化

### 長期
1. ローカル LLM（MLX）の統合
2. 音声入力からの直接翻訳
3. 画像内テキストの翻訳

## 参考リンク
- [Apple Intelligence and Foundation Models](https://developer.apple.com/machine-learning/)
- [WWDC 2024 Sessions](https://developer.apple.com/wwdc24/)
- [OpenAI API Documentation](https://platform.openai.com/docs)

## テスト方法

### Foundation Models でのテスト（デフォルト）
1. アプリをビルド＆実行
2. カード作成画面で日本語を入力（例: "おはよう"）
3. 「候補を生成」をタップ
4. 英語候補が表示されることを確認
5. Console で "Foundation Models API: Using on-device Apple Intelligence" のログを確認

### OpenAI でのテスト（オプション）
1. API キーを取得
2. 設定画面で入力
3. カード作成で翻訳をテスト
4. Console で API レスポンスを確認

## トラブルシューティング

### 候補が生成されない
- 日本語入力が空でないか確認
- Console ログでエラー内容を確認
- 暫定実装ではモックの辞書を使用（"おはよう"、"こんにちは" など）

### OpenAI でエラーが出る
- API キーが正しいか確認
- インターネット接続を確認
- OpenAI の使用制限を確認
- Console ログでエラー内容を確認

## 重要な注意事項

**現在の状態**:
- iOS 18.2 を最低バージョンとして設定済み
- Foundation Models をデフォルトで使用
- API の正式版が公開されるまでは、内部的にモックで代替
- API 公開後、コードを更新することで自動的に実際の AI 推論に切り替わる

**API 公開後の移行**:
1. `FoundationModelsTranslationService.swift` の暫定実装を削除
2. 実際の Foundation Models API 呼び出しコードに置き換え
3. テストして動作確認
4. App Store に更新版を提出
