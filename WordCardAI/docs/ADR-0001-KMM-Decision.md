# ADR 0001: Android 対応戦略

- Date: 2025-11-23
- Status: Accepted

## Context
- 現在は SwiftUI の iOS アプリとして MVP を作成中。将来的に Android への展開を検討している。

## Decision
- 当面は iOS ネイティブ（Swift + SwiftUI）で MVP を開発する。Android 対応は将来的に Kotlin Multiplatform (KMM) を用いてビジネスロジック（API クライアント、データモデル、バリデーション等）を共有し、UI は各プラットフォームでネイティブ実装とする。

## Consequences
- 既存の iOS 実装を活かしつつ、ロジックの分離（ViewModel/Service 層）を厳格に行う必要がある。
- KMM の導入時には Android Studio のセットアップと Gradle/Native の学習コストが発生する。
