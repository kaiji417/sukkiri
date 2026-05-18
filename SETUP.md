# Sukkiri — Xcode プロジェクト セットアップ手順

## 1. プロジェクト作成

1. Xcode を開き **File > New > Project**
2. **iOS > App** を選択
3. 設定:
   - Product Name: `Sukkiri`
   - Bundle Identifier: `com.yourname.sukkiri`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData** にチェック
4. 保存先を選択して作成

---

## 2. ファイル配置

プロジェクト内に以下のグループを作成してファイルをコピー：

```
Sukkiri/
├── SukkiriApp.swift              ← 差し替え
├── DesignSystem/
│   └── DesignSystem.swift
├── Models/
│   └── SwiftDataModels.swift
├── Services/
│   ├── PhotoService.swift
│   └── HapticService.swift
└── Features/
    ├── Onboarding/
    │   └── OnboardingView.swift
    ├── Swipe/
    │   └── SwipeView.swift
    ├── Result/
    │   └── ResultView.swift
    └── Dashboard/
        └── DashboardView.swift
```

---

## 3. Info.plist に追加が必要なキー

Xcode の **Info タブ** (または Info.plist) に以下を追加：

| Key | Value |
|-----|-------|
| `NSPhotoLibraryUsageDescription` | スクリーンショットを整理するために写真へのアクセスが必要です |
| `NSPhotoLibraryAddUsageDescription` | 写真ライブラリへの書き込みに使用します |

---

## 4. Capabilities

**Signing & Capabilities > + Capability** から追加:
- `Photos Library` (自動追加される場合が多い)

---

## 5. Assets.xcassets にカラーを追加

1. Assets.xcassets を開く
2. **+** > **Color Set** を2つ追加:

### SukkiriAccent
- Any Appearance: `#4A7FA5`
- Dark: `#6FA3C8`

### SukkiriBackground
- Any Appearance: `#FAFAFAF`
- Dark: `#111111`

---

## 6. ビルド・実行

```
⌘ + R  →  Simulator (iPhone 15 Pro など iOS 17+)
```

シミュレーターでは PhotoKit は **限定的** にのみ動作します。
実機でのテストを推奨します。

### シミュレーターでテストする場合

Photos アプリにテスト用スクリーンショットを追加:
```bash
# Simulator でスクリーンショットを撮る
⌘ + S  （Simulator 上で）
```

---

## 7. 既知の制限（MVP）

- `fileSize(of:)` はライブラリからローカル保存の画像でのみ正確
- iCloud 写真はネットワーク越しのため初回ロードが遅い場合あり
- `PHAuthorizationStatus.limited` では一部の写真のみ表示

---

## 次フェーズ
- [x] ダッシュボードをタブバーで追加 (`TabView`)
- [ ] Spotlight / ウィジェット連携
- [ ] Vision Framework によるスクショ自動分類
