# Changelog

All notable changes to WordCardAI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added - MVP 完成 🎉

#### アーキテクチャ・ドキュメント
- MVVM アーキテクチャの実装
- 完全なドキュメント整備（ARCHITECTURE.md, UI_DESIGN.md, XCODE_SETUP.md）
- プロジェクト構造の確立

#### データ層
- `CardCollection` モデル: カード集の管理
- `WordCard` モデル: 単語カードの管理
- `AppSettings` モデル: アプリ設定の管理
- `UserDefaultsStorage`: JSON ベースのローカルストレージ実装
- `StorageProtocol`: 将来の拡張性を考慮した抽象化

#### サービス層
- `SettingsService`: ユーザー設定管理（AI候補数: 1-5件）
- `MockTranslationService`: 20種類以上の日本語フレーズ対応
- `TranslationServiceProtocol`: 将来の AI 統合のための抽象化

#### ViewModels
- `CollectionsViewModel`: カード集の CRUD 操作
- `CardsViewModel`: カードの管理、検索、フィルタリング
- `CreateCardViewModel`: カード作成・編集、AI候補生成
- `LearnModeViewModel`: フラッシュカード学習ロジック

#### Views - カード集管理
- `CollectionsListView`: カード集一覧画面
  - カード集の表示（カード数、作成日）
  - スワイプ削除機能
  - 空状態の表示
  - FAB による新規作成
- `CreateCollectionView`: カード集作成シート

#### Views - カード管理
- `CardsListView`: カード一覧画面
  - リアルタイム検索（日本語・英語・タグ）
  - カード数表示
  - 学習モード起動ボタン
  - スワイプ削除
- `CreateEditCardView`: カード作成・編集画面
  - 日本語入力フィールド
  - AI候補生成ボタン（ローディング表示付き）
  - 複数候補の選択UI
  - 英語手動編集
  - メモフィールド
  - タグ入力（カンマ区切り）
  - バリデーション機能

#### Views - 学習機能
- `LearnModeView`: フラッシュカード学習画面
  - カードの自動シャッフル
  - 進捗表示（現在位置/総数、プログレスバー）
  - 答え表示トグル（アニメーション付き）
  - 前へ/次へナビゲーション
  - リセット機能

#### Views - 設定
- `SettingsView`: 設定画面
  - AI候補数の変更（1-5件）
  - データ統計表示（カード集数、カード総数）
  - バージョン情報
  - プライバシーポリシーリンク

#### ユーティリティ
- `Constants`: アプリ全体の定数管理
- `Date+Extensions`: 日付フォーマット拡張
- `String+Extensions`: 文字列操作拡張（trim, tags parsing）

#### UI/UX
- iOS ネイティブデザイン
- ダークモード対応
- Dynamic Type サポート
- VoiceOver 対応（アクセシビリティ）
- エラーハンドリングとユーザーフィードバック
- 直感的なナビゲーションフロー

#### 機能
- ✅ 複数カード集の作成・削除・管理
- ✅ 単語カードの CRUD 操作
- ✅ AI 翻訳候補生成（モック、20+フレーズ対応）
- ✅ フラッシュカード学習モード
- ✅ リアルタイム検索・フィルタリング
- ✅ タグ機能
- ✅ メモ機能
- ✅ 完全オフライン動作
- ✅ データの永続化（UserDefaults + JSON）

### Technical Details
- **Language**: Swift 5.9
- **Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Architecture**: MVVM
- **Navigation**: NavigationStack
- **Storage**: UserDefaults + Codable
- **State Management**: @StateObject, @Published, @EnvironmentObject

## [0.1.0] - 2025-11-23

### Added
- プロジェクト初期セットアップ
- ドキュメント雛形を追加（README, docs/*）
- Xcode プロジェクト作成
