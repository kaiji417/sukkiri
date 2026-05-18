import SwiftUI
import SwiftData

// MARK: - 結果画面

struct ResultView: View {

    let result: SessionResult
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var didSave = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // 結果ヘッダー
                VStack(spacing: Spacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(Color.accent)

                    Text("お疲れさまでした")
                        .font(.sukkiriTitle)

                    Text("今日のセッション")
                        .font(.sukkiriCaption)
                        .foregroundStyle(.secondary)
                }

                // 数字
                HStack(spacing: Spacing.xxl) {
                    StatCard(value: "\(result.deletedCount)", label: "削除", accent: true)
                    StatCard(value: result.freedBytes.formattedFileSize, label: "解放")
                }
                .padding(.horizontal, Spacing.lg)

                // 小テキスト
                if result.deletedCount > 0 {
                    Text("\(result.reviewedCount)枚チェック、\(result.deletedCount)枚整理しました")
                        .font(.sukkiriCaption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("今日は全部残しておきました")
                        .font(.sukkiriCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // ボタン群
                VStack(spacing: Spacing.md) {
                    if result.deletedCount > 0 {
                        Button {
                            generateShareImage()
                        } label: {
                            Label("シェアする", systemImage: "square.and.arrow.up")
                                .font(.sukkiriBody.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(Color.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.sukkiriBody)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .onAppear {
            if !didSave {
                saveSession()
                didSave = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: SwiftData へ保存

    private func saveSession() {
        let record = SessionRecord(
            reviewedCount: result.reviewedCount,
            deletedCount: result.deletedCount,
            freedBytes: result.freedBytes
        )
        modelContext.insert(record)

        // AppStats を更新（なければ作成）
        let descriptor = FetchDescriptor<AppStats>()
        let stats = (try? modelContext.fetch(descriptor))?.first ?? {
            let s = AppStats()
            modelContext.insert(s)
            return s
        }()
        stats.update(with: record)
        try? modelContext.save()
    }

    // MARK: シェア画像生成

    private func generateShareImage() {
        let view = ShareCardView(
            deletedCount: result.deletedCount,
            freedSize: result.freedBytes.formattedFileSize
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showShareSheet = true
        }
    }
}

// MARK: - 統計カード

private struct StatCard: View {
    let value: String
    let label: String
    var accent: Bool = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.sukkiriStat)
                .foregroundStyle(accent ? Color.accent : .primary)
                .minimumScaleFactor(0.5)

            Text(label)
                .font(.sukkiriCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - SNSシェア用縦長カード

struct ShareCardView: View {
    let deletedCount: Int
    let freedSize: String

    var body: some View {
        ZStack {
            Color(red: 0.290, green: 0.498, blue: 0.647) // アクセントカラー固定

            VStack(spacing: Spacing.xl) {
                Spacer()

                Text("Sukkiri")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: Spacing.sm) {
                    Text("\(deletedCount)")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(.white)
                    Text("枚のスクショを整理")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("\(freedSize) 解放")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("今日も1枚整理できました")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, Spacing.xl)
            }
        }
        .frame(width: 300, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - UIActivityViewController ラッパー

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ResultView(result: SessionResult(reviewedCount: 12, deletedCount: 7, freedBytes: 42_000_000))
}
