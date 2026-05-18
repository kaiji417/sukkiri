# Sukkiri（スッキリ）

> 毎朝2分。スクショを1枚ずつスワイプして整理する、ミニマルなiOSアプリ。

---

## アプリの概要

iPhoneに溜まりがちなスクリーンショットを、Tinder形式のスワイプUIで素早く整理するアプリ。

| 操作 | 意味 |
|------|------|
| 右スワイプ | 残す |
| 左スワイプ | 削除マーク |
| セッション終了 | 削除候補を一括削除 |

セッション終了後に「何枚削除・何MB解放」を表示し、SNSシェア画像も生成する。
累計削除数・連続日数（ストリーク）もダッシュボードで確認できる。

---

## 技術スタック

| 領域 | 技術 |
|------|------|
| UI | SwiftUI（iOS 17+） |
| 写真アクセス | PhotoKit（PHPhotoLibrary） |
| データ永続化 | SwiftData |
| グラフ | Swift Charts |
| シェア画像生成 | ImageRenderer |
| Haptic | UIImpactFeedbackGenerator |
| 非同期処理 | Swift Concurrency（async/await） |
| アーキテクチャ | MVVM（@Observable） |
| 将来予定 | Vision Framework（OCR・自動分類） |

---

## ディレクトリ構成

```
Sukkiri/
├── SukkiriApp.swift                  # エントリーポイント・ルート画面切り替え
├── DesignSystem/
│   └── DesignSystem.swift            # カラー・スペーシング・フォント定義
├── Models/
│   └── SwiftDataModels.swift         # SessionRecord / AppStats（SwiftData）
├── Services/
│   ├── PhotoService.swift            # PhotoKit ラッパー（プロトコル設計・テスト可能）
│   └── HapticService.swift          # 触感フィードバック
└── Features/
    ├── Onboarding/
    │   └── OnboardingView.swift      # 初回の写真アクセス許可フロー
    ├── Swipe/
    │   ├── SwipeView.swift           # メインスワイプ画面（コア体験）
    │   └── AlbumPickerView.swift     # フォルダ（アルバム）選択画面
    ├── Result/
    │   └── ResultView.swift          # セッション結果・SNSシェア
    └── Dashboard/
        └── DashboardView.swift       # 累計統計・Swift Chartsグラフ
```

---

## 画面遷移

```
起動
 └─ 初回: OnboardingView（写真アクセス許可）
 └─ 2回目以降: TabView
      ├─ Tab1: MainSwipeView（スワイプ）
      │    ├─ AlbumPickerView（フォルダ選択シート）  ← ← 追加済み
      │    ├─ confirmationDialog（削除確認）
      │    └─ fullScreenCover → ResultView（結果）
      └─ Tab2: DashboardView（累計統計）
```

---

## データモデル

### SessionRecord（SwiftData）
1回の整理セッションを記録する。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| date | Date | セッション日時 |
| reviewedCount | Int | レビューした枚数 |
| deletedCount | Int | 削除した枚数 |
| freedBytes | Int64 | 解放したバイト数 |

### AppStats（SwiftData）
アプリ全体の累計統計。レコードは1件のみ使用する。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| totalDeleted | Int | 累計削除枚数 |
| totalFreedBytes | Int64 | 累計解放容量 |
| currentStreak | Int | 連続日数 |
| lastSessionDate | Date? | 最後のセッション日 |

---

## デザインシステム

**アクセントカラー: スレートブルー**

| モード | HEX |
|--------|-----|
| Light | `#4A7FA5` |
| Dark | `#6FA3C8` |

**背景色**
- Light: `#FAFAFA`
- Dark: `#111111`

**スペーシング**: `Spacing.xs(4)` / `sm(8)` / `md(16)` / `lg(24)` / `xl(40)` / `xxl(64)`

**フォント**: SF Pro（システム）/ 日本語はヒラギノ角ゴ（自動適用）

---

## 主要コンポーネント

### PhotoService（`Services/PhotoService.swift`）

`PhotoServiceProtocol` に準拠しており、テスト時にモックを差し込める設計。

```swift
protocol PhotoServiceProtocol {
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchScreenshots() async -> [PHAsset]
    func fetchAssets(in collection: PHAssetCollection) async -> [PHAsset]  // フォルダ選択用
    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage?
    func deleteAssets(_ assets: [PHAsset]) async throws
    func fileSize(of asset: PHAsset) -> Int64
}
```

### SwipeViewModel（`Features/Swipe/SwipeView.swift`）

- `assets: [PHAsset]` を保持し、`currentIndex` でカーソル管理
- `deleteCandidates: [PHAsset]` に削除予定を蓄積
- `photoSource: PhotoSource` でスクショ/フォルダを切り替え可能

---

## セットアップ（Xcodeプロジェクト作成手順）

詳細は `SETUP.md` を参照。簡易手順：

1. Xcode → New Project → iOS App（SwiftUI・SwiftData）
2. このフォルダのファイルをグループ分けしてコピー
3. `Info.plist` に以下を追加：
   - `NSPhotoLibraryUsageDescription`：「スクリーンショットを整理するために写真へのアクセスが必要です」
   - `NSPhotoLibraryAddUsageDescription`：「写真ライブラリへの書き込みに使用します」
4. `Assets.xcassets` に `SukkiriAccent` / `SukkiriBackground` カラーセットを追加
5. 実機でビルド（PhotoKitは実機推奨）

---

## 未実装・将来対応予定

| 機能 | 優先度 | メモ |
|------|--------|------|
| TabView でダッシュボード切り替え | 高 | 【完了】実装済み |
| Vision Framework でOCR・自動分類 | 中 | PhotoServiceProtocol に差し込み口あり |
| ホーム画面ウィジェット | 中 | WidgetKit、SwiftData共有が必要 |
| Siriショートカット | 低 | App Intents フレームワーク |
| iPad対応 | 低 | レイアウト調整が必要 |
| 写真編集・フィルター | 対象外 | MVPスコープ外 |
| AIによる削除推薦スコア | 将来 | CoreML + Vision |

---

## エラーハンドリング方針

| 状況 | 対処 |
|------|------|
| 写真アクセス拒否 | 設定アプリへ誘導（`UIApplication.openSettingsURLString`） |
| 写真削除失敗 | ユーザーキャンセルの可能性が高いので静かに戻る |
| 画像読み込み失敗 | プレースホルダー + スキップボタン表示 |
| iCloud写真の遅延 | `isNetworkAccessAllowed = true` で対応、ローディング表示 |

---

## リリースチェックリスト

- [ ] 実機で全5画面の動作確認
- [ ] iCloud写真でのテスト
- [ ] Limited アクセス権限でのテスト
- [ ] Xcode Instruments でメモリリーク確認
- [ ] アプリアイコン（1024×1024 PNG）
- [ ] スクリーンショット（6.5インチ用・最低3枚）
- [ ] プライバシーポリシーURL（写真アクセス理由の明記が必須）
- [ ] Apple Developer Program 登録（年$99）
- [ ] App Store Connect にメタデータ入力（日英）
- [ ] TestFlight でβテスト
- [ ] App Store 審査申請

---

## 開発メモ・決定事項

**なぜ SwiftData か**
Core Data より宣言的で SwiftUI との相性が良い。MVPの統計データ量ならオーバーヘッドなし。

**なぜ PHAuthorizationStatus.limited でも動かすか**
Limited アクセスでも整理の価値はある。ただし表示されるのは許可された写真のみ。

**PhotoSource の設計（フォルダ選択追加後）**
`enum PhotoSource { case screenshots; case album(PHAssetCollection) }` で切り替え。
スクショが本筋なのでデフォルトは `.screenshots`。アルバム選択はオプション扱い。

**fileSize の精度**
`PHAssetResource` 経由のサイズはiCloudダウンロード前でも参照可能だが、ローカル未保存の場合は0になることがある。許容済み。
