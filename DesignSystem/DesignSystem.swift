import SwiftUI

// MARK: - カラーパレット（スレートブルー採用）

extension Color {
    /// アクセント: ライト #4A7FA5 / ダーク #6FA3C8
    static let sukkiriAccent = Color("SukkiriAccent")

    /// 背景: ライト White / ダーク Black に近いグレー
    static let sukkiriBackground = Color("SukkiriBackground")

    /// 削除カードオーバーレイ
    static let deleteOverlay = Color.red.opacity(0.15)

    /// 保持カードオーバーレイ
    static let keepOverlay = Color.sukkiriAccent.opacity(0.15)
}

// MARK: - Assets.xcassets に追加すべきカラー定義
// （Xcodeで手動追加 or コードで Color(red:green:blue:) で代替可能）
//
// SukkiriAccent:
//   Light:  R:0.290 G:0.498 B:0.647  (#4A7FA5)
//   Dark:   R:0.435 G:0.639 B:0.784  (#6FA3C8)
//
// SukkiriBackground:
//   Light:  #FAFAFA
//   Dark:   #111111

// MARK: - フォールバック（Assets未設定の場合でも動く）

extension Color {
    static var accent: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.435, green: 0.639, blue: 0.784, alpha: 1)
                : UIColor(red: 0.290, green: 0.498, blue: 0.647, alpha: 1)
        })
    }

    static var appBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1)
                : UIColor(red: 0.980, green: 0.980, blue: 0.980, alpha: 1)
        })
    }
}

// MARK: - スペーシング

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 40
    static let xxl: CGFloat = 64
}

// MARK: - タイポグラフィ

extension Font {
    static var sukkiriLargeTitle: Font { .system(size: 34, weight: .bold, design: .default) }
    static var sukkiriTitle: Font { .system(size: 22, weight: .semibold, design: .default) }
    static var sukkiriBody: Font { .system(size: 17, weight: .regular, design: .default) }
    static var sukkiriCaption: Font { .system(size: 13, weight: .regular, design: .default) }
    static var sukkiriStat: Font { .system(size: 48, weight: .thin, design: .default) }
}
