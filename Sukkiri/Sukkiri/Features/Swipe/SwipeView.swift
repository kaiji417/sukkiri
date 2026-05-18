import SwiftUI
import Photos

// MARK: - スワイプ方向

enum SwipeDirection {
    case keep
    case delete
}

// MARK: - ViewModel

@Observable
final class SwipeViewModel {

    static let dailyLimit = 30

    var assets: [PHAsset] = []
    var currentIndex: Int = 0
    var isLoading = true
    var currentImage: UIImage?
    var isLoadingImage = false

    var deleteCandidates: [PHAsset] = []
    var keptCount: Int = 0

    // 今セッションでレビューしたアセットID（スワイプ完了後にUserDefaultsへ反映）
    private(set) var sessionReviewedIDs: Set<String> = []

    struct SwipeAction {
        let direction: SwipeDirection
        let asset: PHAsset
    }
    var lastAction: SwipeAction?
    var canUndo: Bool { lastAction != nil }
    var nextImageCache: UIImage?

    var showDeleteConfirmation = false
    var showResult = false
    var showAlbumPicker = false
    var sessionResult: SessionResult?

    var photoSource: PhotoSource = .screenshots

    private let photoService: PhotoServiceProtocol
    private let haptics = HapticService()

    var current: PHAsset? { assets[safe: currentIndex] }
    var remaining: Int { max(0, assets.count - currentIndex) }
    var progress: Double {
        guard assets.count > 0 else { return 0 }
        return Double(currentIndex) / Double(assets.count)
    }

    init(photoService: PhotoServiceProtocol = PhotoService()) {
        self.photoService = photoService
    }

    // MARK: ロード

    func loadAssets(reviewedIDs: Set<String> = []) async {
        isLoading = true
        currentIndex = 0
        deleteCandidates = []
        keptCount = 0
        currentImage = nil
        lastAction = nil
        nextImageCache = nil
        sessionReviewedIDs = []

        switch photoSource {
        case .screenshots:
            assets = await photoService.fetchUnreviewedScreenshots(
                reviewedIDs: reviewedIDs,
                limit: Self.dailyLimit
            )
        case .album(let collection):
            assets = await photoService.fetchAssets(in: collection)
        }

        isLoading = false
        await loadCurrentImage()
    }

    func changeSource(_ newSource: PhotoSource, reviewedIDs: Set<String> = []) async {
        guard newSource != photoSource else { return }
        photoSource = newSource
        await loadAssets(reviewedIDs: reviewedIDs)
    }

    // MARK: スワイプ処理

    func swipe(_ direction: SwipeDirection) async {
        guard let currentAsset = current else { return }

        sessionReviewedIDs.insert(currentAsset.localIdentifier)
        lastAction = SwipeAction(direction: direction, asset: currentAsset)

        switch direction {
        case .keep:
            haptics.keep()
            keptCount += 1
        case .delete:
            haptics.delete()
            deleteCandidates.append(currentAsset)
        }

        currentIndex += 1
        await loadCurrentImage()
    }

    func loadCurrentImage() async {
        guard let asset = current else { currentImage = nil; return }
        isLoadingImage = true
        let scale = UIScreen.main.scale
        let size = CGSize(
            width: UIScreen.main.bounds.width * scale,
            height: UIScreen.main.bounds.height * scale
        )

        if let cached = nextImageCache {
            currentImage = cached
            nextImageCache = nil
        } else {
            currentImage = await photoService.loadImage(for: asset, targetSize: size)
        }

        isLoadingImage = false

        if let nextAsset = assets[safe: currentIndex + 1] {
            Task {
                nextImageCache = await photoService.loadImage(for: nextAsset, targetSize: size)
            }
        }
    }

    func prepareHaptics() {
        haptics.prepareHaptics()
    }

    func undo() {
        guard let action = lastAction, currentIndex > 0 else { return }
        currentIndex -= 1

        switch action.direction {
        case .keep:
            keptCount = max(0, keptCount - 1)
        case .delete:
            if let idx = deleteCandidates.lastIndex(where: { $0.localIdentifier == action.asset.localIdentifier }) {
                deleteCandidates.remove(at: idx)
            }
        }

        sessionReviewedIDs.remove(action.asset.localIdentifier)
        nextImageCache = nil
        lastAction = nil
        Task { await loadCurrentImage() }
    }

    // MARK: セッション終了

    func endSession() {
        guard !deleteCandidates.isEmpty else {
            finishWithResult(deleted: 0, freedBytes: 0)
            return
        }
        showDeleteConfirmation = true
    }

    func confirmDeletion() async {
        let targets = deleteCandidates
        let totalBytes = targets.reduce(Int64(0)) { $0 + photoService.fileSize(of: $1) }
        do {
            try await photoService.deleteAssets(targets)
            haptics.sessionComplete()
            finishWithResult(deleted: targets.count, freedBytes: totalBytes)
        } catch {
            showDeleteConfirmation = false
        }
    }

    private func finishWithResult(deleted: Int, freedBytes: Int64) {
        sessionResult = SessionResult(
            reviewedCount: currentIndex,
            deletedCount: deleted,
            freedBytes: freedBytes
        )
        showResult = true
    }

    // MARK: 未レビュー数カウント（省エネモード通知用）

    func countRemaining(reviewedIDs: Set<String>) async -> Int {
        await photoService.countUnreviewedScreenshots(reviewedIDs: reviewedIDs)
    }
}

// MARK: - セッション結果 DTO

struct SessionResult {
    let reviewedCount: Int
    let deletedCount: Int
    let freedBytes: Int64
}

// MARK: - 紙吹雪ビュー

struct ConfettiView: View {

    struct Particle {
        var x: CGFloat
        var startY: CGFloat
        var speed: CGFloat
        var rotSpeed: Double
        var color: Color
        var width: CGFloat
        var height: CGFloat
        var isCircle: Bool
    }

    @State private var particles: [Particle] = []
    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                for p in particles {
                    let x = p.x * size.width
                    let rawY = p.startY * size.height + CGFloat(t) * p.speed * size.height
                    let cycleH = size.height * 1.6
                    let y = rawY.truncatingRemainder(dividingBy: cycleH)
                    guard y < size.height + 20 else { continue }

                    let angle = Angle.degrees(t * p.rotSpeed)
                    let path: Path = p.isCircle
                        ? Path(ellipseIn: CGRect(x: -p.width/2, y: -p.height/2, width: p.width, height: p.width))
                        : Path(CGRect(x: -p.width/2, y: -p.height/2, width: p.width, height: p.height))

                    ctx.drawLayer { c in
                        c.translateBy(x: x, y: y)
                        c.rotate(by: angle)
                        c.fill(path, with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            startDate = .now
            guard particles.isEmpty else { return }
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink,
                                   .cyan, .mint, Color(red: 0.29, green: 0.50, blue: 0.65)]
            particles = (0..<120).map { _ in
                Particle(
                    x: .random(in: 0.02...0.98),
                    startY: .random(in: -0.6 ... -0.02),
                    speed: .random(in: 0.15...0.4),
                    rotSpeed: Double.random(in: 100...360) * (Bool.random() ? 1 : -1),
                    color: colors.randomElement()!,
                    width: .random(in: 8...14),
                    height: .random(in: 4...8),
                    isCircle: Bool.random()
                )
            }
        }
    }
}

// MARK: - メインスワイプ画面

struct MainSwipeView: View {

    @State private var viewModel = SwipeViewModel()
    @State private var dragOffset: CGSize = .zero
    private let swipeThreshold: CGFloat = 80

    // 毎日セッション管理
    @AppStorage("lastDailySessionTimestamp") private var lastDailySessionTimestamp: Double = 0
    @AppStorage("isPastPhotosDigested") private var isPastPhotosDigested: Bool = false

    // セッション完了後の処理済みフラグ（二重実行防止）
    @State private var didHandleCompletion = false

    private var isTodayComplete: Bool {
        guard lastDailySessionTimestamp > 0 else { return false }
        let date = Date(timeIntervalSince1970: lastDailySessionTimestamp)
        return Calendar.current.isDateInToday(date)
    }

    private var reviewedIDs: Set<String> {
        UserDefaults.standard.reviewedScreenshotIDs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if isTodayComplete {
                    todayCompleteView
                } else if viewModel.isLoading {
                    loadingView
                } else if viewModel.assets.isEmpty {
                    emptyView
                } else if viewModel.remaining == 0 {
                    allDonePrompt
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTodayComplete && !viewModel.isLoading && viewModel.remaining > 0 {
                    toolbarContent
                }
            }
        }
        .task { await viewModel.loadAssets(reviewedIDs: reviewedIDs) }
        .onChange(of: viewModel.photoSource) { _, newSource in
            Task { await viewModel.changeSource(newSource, reviewedIDs: reviewedIDs) }
        }
        .sheet(isPresented: $viewModel.showAlbumPicker) {
            AlbumPickerView(selectedSource: $viewModel.photoSource)
        }
        .confirmationDialog(
            "\(viewModel.deleteCandidates.count)枚を削除しますか？",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task { await viewModel.confirmDeletion() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した写真は「最近削除した項目」に移動します")
        }
        .fullScreenCover(isPresented: $viewModel.showResult) {
            if let result = viewModel.sessionResult {
                ResultView(result: result)
            }
        }
    }

    // MARK: 今日は完了済み画面

    private var todayCompleteView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "moon.stars")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Color.accent)
            Text("今日の分はすべて完了しています！")
                .font(.sukkiriTitle)
                .multilineTextAlignment(.center)
            Text("また明日お会いしましょう")
                .font(.sukkiriBody)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.xl)
    }

    // MARK: メインコンテンツ

    private var mainContent: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            Spacer()
            cardView
                .padding(.horizontal, Spacing.md)
            Spacer()
            swipeHints
                .padding(.bottom, Spacing.lg)
        }
    }

    // MARK: プログレスバー

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("残り \(viewModel.remaining) 枚")
                    .font(.sukkiriCaption).foregroundStyle(.secondary)
                Spacer()
                Text("削除予定 \(viewModel.deleteCandidates.count) 枚")
                    .font(.sukkiriCaption).foregroundStyle(Color.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accent)
                        .frame(width: geo.size.width * viewModel.progress, height: 3)
                        .animation(.spring(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: カード

    private var cardView: some View {
        ZStack {
            if dragOffset.width < -20 { deleteLabel }
            if dragOffset.width > 20  { keepLabel }

            photoCard
                .offset(dragOffset)
                .rotationEffect(.degrees(dragOffset.width / 20))
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
                .gesture(dragGesture)
        }
    }

    private var photoCard: some View {
        Group {
            if let image = viewModel.currentImage {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                    .id(viewModel.currentIndex)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .overlay {
                        if viewModel.isLoadingImage {
                            ProgressView()
                        } else {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "photo")
                                    .font(.system(size: 40, weight: .thin)).foregroundStyle(.secondary)
                                Button("スキップ") { Task { await viewModel.swipe(.keep) } }
                                    .font(.sukkiriCaption).foregroundStyle(Color.accent)
                            }
                        }
                    }
                    .frame(maxHeight: 500)
            }
        }
    }

    private var deleteLabel: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.08))
            .overlay(alignment: .topTrailing) {
                Text("削除").font(.sukkiriBody.weight(.semibold)).foregroundStyle(.red).padding(Spacing.md)
            }
            .allowsHitTesting(false)
    }

    private var keepLabel: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color.accent.opacity(0.08))
            .overlay(alignment: .topLeading) {
                Text("残す").font(.sukkiriBody.weight(.semibold)).foregroundStyle(Color.accent).padding(Spacing.md)
            }
            .allowsHitTesting(false)
    }

    private var swipeHints: some View {
        HStack(spacing: 0) {
            Label("削除", systemImage: "arrow.left").font(.sukkiriCaption).foregroundStyle(.secondary)
            Spacer()
            Label("残す", systemImage: "arrow.right").font(.sukkiriCaption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: ドラッグジェスチャー

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragOffset == .zero { viewModel.prepareHaptics() }
                dragOffset = value.translation
            }
            .onEnded { value in
                let direction: SwipeDirection? =
                    value.translation.width >  swipeThreshold ? .keep   :
                    value.translation.width < -swipeThreshold ? .delete : nil

                if let direction {
                    withAnimation(.spring(duration: 0.35)) {
                        dragOffset = CGSize(width: direction == .keep ? 600 : -600, height: value.translation.height)
                    }
                    Task {
                        await viewModel.swipe(direction)
                        withAnimation(.spring(duration: 0.2)) { dragOffset = .zero }
                    }
                } else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.3)) { dragOffset = .zero }
                }
            }
    }

    // MARK: 空・ロード・完了

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("読み込んでいます").font(.sukkiriCaption).foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: isPastPhotosDigested ? "sparkles" : "photo.badge.checkmark")
                .font(.system(size: 56, weight: .thin)).foregroundStyle(Color.accent)
            Text(isPastPhotosDigested
                 ? "スクショはすべてスッキリ済み！"
                 : "\(viewModel.photoSource.displayName)に写真がありません")
                .font(.sukkiriTitle)
                .multilineTextAlignment(.center)
            Text(isPastPhotosDigested
                 ? "10枚溜まったらお知らせします"
                 : "別のフォルダを選んでみましょう")
                .font(.sukkiriCaption).foregroundStyle(.secondary)
            if !isPastPhotosDigested {
                Button("フォルダを変更") { viewModel.showAlbumPicker = true }
                    .font(.sukkiriCaption).foregroundStyle(Color.accent)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.xl)
    }

    private var allDonePrompt: some View {
        ZStack {
            ConfettiView()

            VStack(spacing: Spacing.xl) {
                Spacer()
                VStack(spacing: Spacing.md) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(Color.accent)
                    Text("今日もスッキリ！").font(.sukkiriTitle)
                    Text("削除予定: \(viewModel.deleteCandidates.count) 枚")
                        .font(.sukkiriBody).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    viewModel.endSession()
                } label: {
                    Text("セッションを終了する")
                        .font(.sukkiriBody.weight(.medium))
                        .frame(maxWidth: .infinity).padding(.vertical, Spacing.md)
                        .background(Color.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
        }
        .task {
            guard !didHandleCompletion else { return }
            didHandleCompletion = true
            await handleDailySessionComplete()
        }
    }

    // MARK: ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button { viewModel.showAlbumPicker = true } label: {
                HStack(spacing: 4) {
                    Text(viewModel.photoSource.displayName)
                        .font(.sukkiriBody.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            if viewModel.canUndo {
                Button(action: { viewModel.undo() }) {
                    Label("元に戻す", systemImage: "arrow.uturn.backward")
                }
                .font(.sukkiriCaption).foregroundStyle(Color.accent)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("今日はここまで") { viewModel.endSession() }
                .font(.sukkiriCaption).foregroundStyle(Color.accent)
        }
    }

    // MARK: セッション完了処理

    private func handleDailySessionComplete() async {
        // 今セッションでレビューしたIDをUserDefaultsに保存
        var ids = reviewedIDs
        ids.formUnion(viewModel.sessionReviewedIDs)
        UserDefaults.standard.reviewedScreenshotIDs = ids

        // 日付を保存（今日は完了扱い）
        lastDailySessionTimestamp = Date.now.timeIntervalSince1970

        // 未レビュー残数を確認
        let remaining = await viewModel.countRemaining(reviewedIDs: ids)
        let isNowDigested = remaining == 0

        if isNowDigested && !isPastPhotosDigested {
            isPastPhotosDigested = true
        }

        // 省エネモードの場合は通知をスケジュール
        if isPastPhotosDigested {
            await NotificationService.shared.scheduleIfNeeded(unreviewedCount: remaining)
        }
    }


}

// MARK: - Array 安全アクセス

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview { MainSwipeView() }
