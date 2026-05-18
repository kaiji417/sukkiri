import UIKit

// MARK: - スワイプ完了時の触感フィードバック
// UIImpactFeedbackGenerator をラップして、SwiftUI から呼びやすくする

final class HapticService {

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    init() {
        // 初回のみ
        prepareHaptics()
    }

    /// フィードバックの準備（レイテンシを下げるためジェスチャー開始時に呼ぶ）
    func prepareHaptics() {
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    /// 右スワイプ（残す）
    func keep() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// 左スワイプ（削除）
    func delete() {
        mediumImpact.impactOccurred(intensity: 1.0)
    }

    /// セッション完了
    func sessionComplete() {
        notificationFeedback.notificationOccurred(.success)
    }
}
