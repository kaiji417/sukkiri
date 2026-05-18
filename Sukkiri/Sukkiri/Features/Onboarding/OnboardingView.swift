import SwiftUI
import Photos

// MARK: - ViewModel

@Observable
final class OnboardingViewModel {

    enum State {
        case idle
        case requesting
        case authorized
        case denied
    }

    var state: State = .idle
    private let photoService: PhotoServiceProtocol

    init(photoService: PhotoServiceProtocol = PhotoService()) {
        self.photoService = photoService
    }

    func requestPermission() async {
        state = .requesting
        let status = await photoService.requestAuthorization()
        switch status {
        case .authorized, .limited:
            state = .authorized
        default:
            state = .denied
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - オンボーディング画面（初回のみ表示）

struct OnboardingView: View {

    @State private var viewModel = OnboardingViewModel()
    var onAuthorized: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // アイコン＋アプリ名
                VStack(spacing: Spacing.md) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(Color.accent)

                    Text("Sukkiri")
                        .font(.sukkiriLargeTitle)
                        .foregroundStyle(.primary)

                    Text("毎朝2分。スクショを1枚ずつ\nスワイプして整理しましょう。")
                        .font(.sukkiriBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // 使い方ヒント
                VStack(spacing: Spacing.lg) {
                    HintRow(icon: "arrow.right.circle", text: "右スワイプで残す")
                    HintRow(icon: "arrow.left.circle", text: "左スワイプで削除")
                    HintRow(icon: "checkmark.circle", text: "まとめて削除して容量スッキリ")
                }

                Spacer()

                // アクションボタン
                actionButton
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .authorized {
                onAuthorized()
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.state {
        case .idle, .requesting:
            Button {
                Task { await viewModel.requestPermission() }
            } label: {
                HStack {
                    if viewModel.state == .requesting {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.state == .requesting ? "確認中…" : "写真へのアクセスを許可する")
                        .font(.sukkiriBody.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.state == .requesting)

        case .authorized:
            EmptyView()

        case .denied:
            VStack(spacing: Spacing.md) {
                Text("写真へのアクセスが必要です")
                    .font(.sukkiriCaption)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.openSettings()
                } label: {
                    Text("設定アプリを開く")
                        .font(.sukkiriBody.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}

// MARK: - ヒント行

private struct HintRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .thin))
                .foregroundStyle(Color.accent)
                .frame(width: 32)

            Text(text)
                .font(.sukkiriBody)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onAuthorized: {})
}
