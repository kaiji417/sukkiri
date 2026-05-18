import SwiftUI
import Photos

// MARK: - アルバム選択シート
// スクショが本筋なので、スクショ行を先頭に固定して他アルバムをその下に並べる

struct AlbumPickerView: View {

    @Binding var selectedSource: PhotoSource
    @Environment(\.dismiss) private var dismiss

    private let photoService: PhotoServiceProtocol
    @State private var albums: [PHAssetCollection] = []
    @State private var isLoading = true

    init(selectedSource: Binding<PhotoSource>, photoService: PhotoServiceProtocol = PhotoService()) {
        self._selectedSource = selectedSource
        self.photoService = photoService
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("読み込み中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // スクショは常に先頭に固定
                        sourceRow(
                            icon: "camera.viewfinder",
                            title: "スクリーンショット",
                            subtitle: "おすすめ",
                            source: .screenshots
                        )

                        if !albums.isEmpty {
                            Section("その他のアルバム") {
                                ForEach(albums, id: \.localIdentifier) { album in
                                    sourceRow(
                                        icon: "photo.on.rectangle",
                                        title: album.localizedTitle ?? "アルバム",
                                        subtitle: albumCountText(album),
                                        source: .album(album)
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("整理するフォルダ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .task {
            albums = await photoService.fetchUserAlbums()
            isLoading = false
        }
    }

    // MARK: 行コンポーネント

    private func sourceRow(
        icon: String,
        title: String,
        subtitle: String,
        source: PhotoSource
    ) -> some View {
        Button {
            selectedSource = source
            dismiss()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .thin))
                    .foregroundStyle(Color.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.sukkiriBody)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.sukkiriCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 現在の選択に✓
                if selectedSource == source {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func albumCountText(_ album: PHAssetCollection) -> String {
        let count = PHAsset.fetchAssets(in: album, options: nil).count
        return "\(count)枚"
    }
}

#Preview {
    AlbumPickerView(selectedSource: .constant(.screenshots))
}
