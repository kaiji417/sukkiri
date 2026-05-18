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

    var assets: [PHAsset] = []
    var currentIndex: Int = 0
    var isLoading = true
    var currentImage: UIImage?
    var isLoadingImage = false

    var deleteCandidates: [PHAsset] = []
    var keptCount: Int = 0

    // MARK: Undo & Prefetch state
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

    // フォルダ選択：デフォルトはスクショ
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

    // MARK: ロード（ソースに応じて切り替え）

    func loadAssets() async {
        isLoading = true
        currentIndex = 0
        deleteCandidates = []
        keptCount = 0
        currentImage = nil
        lastAction = nil
        nextImageCache = nil

        switch photoSource {
        case .screenshots:
            assets = await photoService.fetchScreenshots()
        case .album(let collection):
            assets = await photoService.fetchAssets(in: collection)
        }

        isLoading = false
        await loadCurrentImage()
    }

    // フォルダ変更時にリセットして再ロード
    func changeSource(_ newSource: PhotoSource) async {
        guard newSource != photoSource else { return }
        photoSource = newSource
        await loadAssets()
    }

    // MARK: スワイプ処理

    func swipe(_ direction: SwipeDirection) async {
        guard let currentAsset = current else { return }

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
            if let lastIndex = deleteCandidates.lastIndex(where: { $0.localIdentifier == action.asset.localIdentifier }) {
                deleteCandidates.remove(at: lastIndex)
            }
        }
        
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
}

// MARK: - セッション結果 DTO

struct SessionResult {
    let reviewedCount: Int
    let deletedCount: Int
    let freedBytes: Int64
}

// MARK: - メインスワイプ画面

struct MainSwipeView: View {

    @State private var viewModel = SwipeViewModel()
    @State private var dragOffset: CGSize = .zero
    private let swipeThreshold: CGFloat = 80

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading {
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
            .toolbar { toolbarContent }
        }
        .task { await viewModel.loadAssets() }
        // フォルダ切り替え時にアセットをリロード
        .onChange(of: viewModel.photoSource) { _, newSource in
            Task { await viewModel.changeSource(newSource) }
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
                if dragOffset == .zero {
                    viewModel.prepareHaptics()
                }
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
            Image(systemName: "photo.badge.checkmark")
                .font(.system(size: 56, weight: .thin)).foregroundStyle(Color.accent)
            Text("\(viewModel.photoSource.displayName)に写真がありません")
                .font(.sukkiriTitle)
            Text("別のフォルダを選んでみましょう")
                .font(.sukkiriCaption).foregroundStyle(.secondary)
            Button("フォルダを変更") { viewModel.showAlbumPicker = true }
                .font(.sukkiriCaption).foregroundStyle(Color.accent)
        }
        .multilineTextAlignment(.center)
    }

    private var allDonePrompt: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .thin)).foregroundStyle(Color.accent)
            Text("全部チェックしました！").font(.sukkiriTitle)
            Text("削除予定: \(viewModel.deleteCandidates.count) 枚")
                .font(.sukkiriBody).foregroundStyle(.secondary)
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
        }
    }

    // MARK: ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // フォルダ名をタップするとアルバム選択シートを開く
        ToolbarItem(placement: .principal) {
            Button {
                viewModel.showAlbumPicker = true
            } label: {
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
}

// MARK: - Array 安全アクセス

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview { MainSwipeView() }
