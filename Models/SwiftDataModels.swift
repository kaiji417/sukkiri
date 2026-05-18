import SwiftData
import Foundation

// MARK: - セッション記録（1回の整理セッション = 1レコード）

@Model
final class SessionRecord {
    var date: Date
    var reviewedCount: Int      // レビューした枚数
    var deletedCount: Int       // 削除した枚数
    var freedBytes: Int64       // 解放したバイト数

    init(date: Date = .now, reviewedCount: Int, deletedCount: Int, freedBytes: Int64) {
        self.date = date
        self.reviewedCount = reviewedCount
        self.deletedCount = deletedCount
        self.freedBytes = freedBytes
    }
}

// MARK: - アプリ全体の累計統計（シングルトン的に1レコードのみ使用）

@Model
final class AppStats {
    var totalDeleted: Int
    var totalFreedBytes: Int64
    var currentStreak: Int          // 連続日数
    var lastSessionDate: Date?

    init() {
        self.totalDeleted = 0
        self.totalFreedBytes = 0
        self.currentStreak = 0
        self.lastSessionDate = nil
    }

    /// セッション完了後に統計を更新する
    func update(with session: SessionRecord) {
        totalDeleted += session.deletedCount
        totalFreedBytes += session.freedBytes
        updateStreak(sessionDate: session.date)
        lastSessionDate = session.date
    }

    private func updateStreak(sessionDate: Date) {
        guard let last = lastSessionDate else {
            currentStreak = 1
            return
        }

        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: sessionDate)
        let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        switch diff {
        case 0:
            // 同日は継続（カウントしない）
            break
        case 1:
            currentStreak += 1
        default:
            // 途切れた
            currentStreak = 1
        }
    }
}
