import SwiftData
import Foundation

// MARK: - セッション記録（1回の整理セッション = 1レコード）

@Model
final class SessionRecord {
    var date: Date
    var reviewedCount: Int
    var deletedCount: Int
    var freedBytes: Int64

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
    var currentStreak: Int
    var lastSessionDate: Date?
    var isPastPhotosDigested: Bool

    init() {
        self.totalDeleted = 0
        self.totalFreedBytes = 0
        self.currentStreak = 0
        self.lastSessionDate = nil
        self.isPastPhotosDigested = false
    }

    func update(with session: SessionRecord, digested: Bool) {
        totalDeleted += session.deletedCount
        totalFreedBytes += session.freedBytes
        updateStreak(sessionDate: session.date)
        lastSessionDate = session.date
        if digested { isPastPhotosDigested = true }
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
        case 0: break
        case 1: currentStreak += 1
        default: currentStreak = 1
        }
    }
}

// MARK: - UserDefaults helper（レビュー済みアセットID管理）

extension UserDefaults {
    private static let reviewedKey = "sukkiri.reviewedAssetIDs"

    var reviewedScreenshotIDs: Set<String> {
        get { Set((array(forKey: Self.reviewedKey) as? [String]) ?? []) }
        set { set(Array(newValue), forKey: Self.reviewedKey) }
    }
}
