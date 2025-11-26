# アーキテクチャ設計書

作成日: 2025-11-23

## 概要

WordCardAI は MVVM (Model-View-ViewModel) パターンを採用した SwiftUI ベースの iOS アプリケーションです。
オフライン優先、オンデバイス AI、シンプルな UX を重視した設計となっています。

## アーキテクチャパターン

### MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────────────┐
│                        View Layer                        │
│  (SwiftUI Views - CollectionsListView, CardsListView...)│
│                           ↕                              │
│                    ViewModel Layer                       │
│  (ObservableObject - CollectionsViewModel, CardsVM...)  │
│                           ↕                              │
│                      Service Layer                       │
│    (TranslationService, SettingsService, Storage)       │
│                           ↕                              │
│                       Model Layer                        │
│        (WordCard, CardCollection - Codable/ID)          │
└─────────────────────────────────────────────────────────┘
```

## ディレクトリ構成

```
WordCardAI/
├── WordCardAIApp.swift          # アプリエントリーポイント
├── Models/                       # データモデル
│   ├── WordCard.swift
│   ├── CardCollection.swift
│   └── AppSettings.swift
├── ViewModels/                   # ビジネスロジック
│   ├── CollectionsViewModel.swift
│   ├── CardsViewModel.swift
│   ├── CreateCardViewModel.swift
│   └── LearnModeViewModel.swift
├── Views/                        # UI層
│   ├── Collections/
│   │   ├── CollectionsListView.swift
│   │   └── CreateCollectionView.swift
│   ├── Cards/
│   │   ├── CardsListView.swift
│   │   ├── CreateEditCardView.swift
│   │   └── CardRow.swift
│   ├── Learn/
│   │   └── LearnModeView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/                     # サービス層
│   ├── Storage/
│   │   ├── StorageProtocol.swift
│   │   └── UserDefaultsStorage.swift
│   ├── Translation/
│   │   ├── TranslationServiceProtocol.swift
│   │   └── MockTranslationService.swift
│   └── SettingsService.swift
├── Utilities/                    # ユーティリティ
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   └── String+Extensions.swift
│   └── Constants.swift
└── Assets.xcassets/             # アセット
```

## データフロー

### カード作成フロー

1. ユーザーが `CreateEditCardView` で日本語を入力
2. `CreateCardViewModel` が `TranslationService` に翻訳リクエスト
3. `TranslationService` がオンデバイスAIで英語候補を生成（1-5件）
4. ViewModel が候補を View に渡して表示
5. ユーザーが候補を選択または編集
6. ViewModel が `StorageProtocol` を通じて `WordCard` を永続化
7. `CardsViewModel` が更新を検知して一覧を更新

### データ永続化フロー

1. ViewModel が CRUD 操作を実行
2. `StorageProtocol` の実装 (`UserDefaultsStorage`) が呼び出される
3. モデルが JSON に Encode される
4. UserDefaults に保存される
5. アプリ再起動時に Decode されて復元される

## 主要コンポーネント

### Models

- **CardCollection**: カード集を表現するモデル
  - id (UUID), title (String), createdAt (Date)
  
- **WordCard**: 単語カードを表現するモデル
  - id (UUID), collectionId (UUID), japanese (String), english (String)
  - candidates ([String]), note (String?), tags ([String]), createdAt (Date)

- **AppSettings**: アプリ設定を表現するモデル
  - candidateCount (Int: 1-5), serverFallbackEnabled (Bool)

### ViewModels

- **CollectionsViewModel**: カード集の管理
  - カード集の作成、削除、取得
  
- **CardsViewModel**: 単語カードの管理
  - カードの一覧表示、検索、削除、並び替え
  
- **CreateCardViewModel**: カード作成・編集
  - AI候補の生成、カードの保存
  
- **LearnModeViewModel**: 学習モード
  - フラッシュカード表示、シャッフル、進捗管理

### Services

- **StorageProtocol / UserDefaultsStorage**
  - ローカルストレージへの保存・読み込み
  - JSON Encode/Decode
  
- **TranslationServiceProtocol / MockTranslationService**
  - 日本語→英語の翻訳候補生成
  - 初期実装はモックサービス（将来的に Apple Translation API に差し替え可能）
  
- **SettingsService**
  - ユーザー設定の管理

## 技術スタック

- **UI Framework**: SwiftUI (iOS 16.0+)
- **Architecture**: MVVM
- **Navigation**: NavigationStack (iOS 16+)
- **State Management**: @StateObject, @ObservableObject, @Published
- **Persistence**: UserDefaults + Codable (JSON)
- **AI Translation**: Mock Service (将来的に Apple Translation Framework)
- **Dependency Injection**: Constructor Injection

## 設計原則

### 1. オフライン優先
- すべてのデータはローカルに保存
- ネットワーク不要で完全に動作
- AI翻訳もオンデバイスで実行（将来実装）

### 2. プロトコル指向設計
- `StorageProtocol`, `TranslationServiceProtocol` による抽象化
- テスト容易性と将来の差し替え可能性を確保

### 3. SwiftUI ベストプラクティス
- View は薄く、ロジックは ViewModel に集約
- @Published による Reactive な状態管理
- PreviewProvider による開発時プレビュー

### 4. ユーザー体験優先
- シンプルで直感的な UI
- 最小限のタップ数でタスク完了
- エラーハンドリングとフィードバック

## 将来の拡張性

### Phase 2 以降で検討する機能

- **Apple Translation Framework 統合**
  - オンデバイス翻訳の実装
  - 言語パックのダウンロード管理

- **Core Data / SwiftData への移行**
  - より高速な検索・フィルタリング
  - 大量データの効率的な管理

- **iCloud 同期**
  - CloudKit を使った複数デバイス間の同期

- **ウィジェット対応**
  - ホーム画面でランダムなカードを表示

- **Kotlin Multiplatform (KMM) 対応**
  - Android 版の開発（ADR-0001参照）

## セキュリティとプライバシー

- ユーザーデータは端末内にのみ保存
- デフォルトでは外部サーバーにデータ送信なし
- サーバー機能利用時は明示的な同意が必要
- App Store プライバシーラベル: データ収集なし

## パフォーマンス考慮事項

- カード一覧の遅延読み込み（将来的に必要になった場合）
- 検索機能の最適化
- AI翻訳のタイムアウト処理
- メモリ効率的な画像・データ管理

---

このアーキテクチャは MVP の要件を満たしつつ、将来の拡張性を考慮した設計となっています。
