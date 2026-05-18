import SwiftUI

struct ToolsView: View {

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    premiumSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.appBackground)
            .navigationTitle("ツール")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("プレミアム機能", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("プレミアム機能（近日公開）")
                .font(.sukkiriCaption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)

            premiumButton(
                title: "動画を圧縮して容量を空ける",
                icon: "film.stack",
                description: "動画ファイルを圧縮してストレージを節約",
                message: "近日公開予定です。お楽しみに！"
            )

            premiumButton(
                title: "重複・類似写真をスキャン",
                icon: "photo.on.rectangle.angled",
                description: "似た写真をまとめて整理・削除",
                message: "プレミアム機能です。近日公開予定！"
            )
        }
    }

    private func premiumButton(
        title: String,
        icon: String,
        description: String,
        message: String
    ) -> some View {
        Button {
            alertMessage = message
            showAlert = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.accent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(.sukkiriBody)
                            .foregroundStyle(.primary)
                        Text("Premium")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accent)
                            .clipShape(Capsule())
                    }
                    Text(description)
                        .font(.sukkiriCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding(Spacing.lg)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ToolsView()
}
