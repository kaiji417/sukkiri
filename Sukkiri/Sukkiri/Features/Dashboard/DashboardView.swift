import SwiftUI
import SwiftData
import Charts

// MARK: - ダッシュボード画面

struct DashboardView: View {

    @Query(sort: \SessionRecord.date, order: .reverse)
    private var sessions: [SessionRecord]

    @Query
    private var statsArray: [AppStats]

    private var stats: AppStats? { statsArray.first }

    private var recentSessions: [SessionRecord] {
        Array(sessions.prefix(7).reversed())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    streakCard
                    totalsRow
                    chartSection
                    historyList
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.appBackground)
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var streakCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("連続日数")
                    .font(.sukkiriCaption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("\(stats?.currentStreak ?? 0)")
                        .font(.sukkiriStat)
                        .foregroundStyle(Color.accent)
                    Text("日")
                        .font(.sukkiriBody)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "flame")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.accent)
        }
        .padding(Spacing.lg)
        .background(Color.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var totalsRow: some View {
        HStack(spacing: Spacing.md) {
            totalCard(value: "\(stats?.totalDeleted ?? 0)", unit: "枚", label: "累計削除")
            totalCard(value: (stats?.totalFreedBytes ?? 0).formattedFileSize, unit: "", label: "累計解放")
        }
    }

    private func totalCard(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.sukkiriCaption)
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .thin))
                if !unit.isEmpty {
                    Text(unit).font(.sukkiriCaption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var chartSection: some View {
        if !recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("直近の削除枚数")
                    .font(.sukkiriCaption)
                    .foregroundStyle(.secondary)
                Chart(recentSessions) { session in
                    BarMark(
                        x: .value("日付", session.date, unit: .day),
                        y: .value("削除枚数", session.deletedCount)
                    )
                    .foregroundStyle(Color.accent.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 140)
            }
            .padding(Spacing.lg)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("履歴")
                    .font(.sukkiriCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.xs)
                VStack(spacing: 1) {
                    ForEach(sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.date, style: .date).font(.sukkiriBody)
                                Text("\(session.reviewedCount)枚チェック")
                                    .font(.sukkiriCaption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(session.deletedCount)枚削除")
                                    .font(.sukkiriBody)
                                    .foregroundStyle(session.deletedCount > 0 ? Color.accent : .secondary)
                                Text(session.freedBytes.formattedFileSize)
                                    .font(.sukkiriCaption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.secondary.opacity(0.06))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [SessionRecord.self, AppStats.self], inMemory: true)
}
