import Photos
import UIKit

// MARK: - Protocol

protocol PhotoServiceProtocol {
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchScreenshots() async -> [PHAsset]
    func fetchUnreviewedScreenshots(reviewedIDs: Set<String>, limit: Int) async -> [PHAsset]
    func countUnreviewedScreenshots(reviewedIDs: Set<String>) async -> Int
    func fetchAssets(in collection: PHAssetCollection) async -> [PHAsset]
    func fetchUserAlbums() async -> [PHAssetCollection]
    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage?
    func deleteAssets(_ assets: [PHAsset]) async throws
    func fileSize(of asset: PHAsset) -> Int64
}

// MARK: - エラー定義

enum PhotoServiceError: LocalizedError {
    case accessDenied
    case deletionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "写真へのアクセスが許可されていません"
        case .deletionFailed(let error):
            return "削除に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - 写真ソース（スクショ固定 or 任意アルバム）

enum PhotoSource: Equatable {
    case screenshots
    case album(PHAssetCollection)

    var displayName: String {
        switch self {
        case .screenshots: return "スクリーンショット"
        case .album(let collection): return collection.localizedTitle ?? "アルバム"
        }
    }

    static func == (lhs: PhotoSource, rhs: PhotoSource) -> Bool {
        switch (lhs, rhs) {
        case (.screenshots, .screenshots): return true
        case (.album(let a), .album(let b)):
            return a.localIdentifier == b.localIdentifier
        default: return false
        }
    }
}

// MARK: - 実装

final class PhotoService: PhotoServiceProtocol {

    private let imageManager = PHCachingImageManager()

    func requestAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchScreenshots() async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    // 未レビューのスクショのみ、新しい順、最大 limit 枚
    func fetchUnreviewedScreenshots(reviewedIDs: Set<String>, limit: Int) async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, stop in
            guard !reviewedIDs.contains(asset.localIdentifier) else { return }
            assets.append(asset)
            if assets.count >= limit { stop.pointee = true }
        }
        return assets
    }

    // 未レビューの総数カウント
    func countUnreviewedScreenshots(reviewedIDs: Set<String>) async -> Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.includeAssetSourceTypes = [.typeUserLibrary]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var count = 0
        result.enumerateObjects { asset, _, _ in
            if !reviewedIDs.contains(asset.localIdentifier) { count += 1 }
        }
        return count
    }

    func fetchAssets(in collection: PHAssetCollection) async -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(in: collection, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func fetchUserAlbums() async -> [PHAssetCollection] {
        var albums: [PHAssetCollection] = []

        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            if PHAsset.fetchAssets(in: collection, options: nil).count > 0 {
                albums.append(collection)
            }
        }

        let smartSubtypes: [PHAssetCollectionSubtype] = [
            .smartAlbumFavorites, .smartAlbumRecentlyAdded,
            .smartAlbumSelfPortraits, .smartAlbumPanoramas, .smartAlbumBursts,
        ]
        for subtype in smartSubtypes {
            let result = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil
            )
            result.enumerateObjects { collection, _, _ in
                if PHAsset.fetchAssets(in: collection, options: nil).count > 0 {
                    albums.append(collection)
                }
            }
        }
        return albums
    }

    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset, targetSize: targetSize,
                contentMode: .aspectFit, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }) { success, error in
                if success {
                    continuation.resume()
                } else if let error {
                    continuation.resume(throwing: PhotoServiceError.deletionFailed(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func fileSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.compactMap { $0.value(forKey: "fileSize") as? Int64 }.reduce(0, +)
    }
}

extension Int64 {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
