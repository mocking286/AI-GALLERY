import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError {
    case imageUnavailable
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            "图片暂时无法下载，请稍后重试"
        case .permissionDenied:
            "需要允许添加到照片，才能保存到相册"
        case .saveFailed:
            "保存失败，请稍后重试"
        }
    }
}

nonisolated enum PhotoLibrarySaver {
    static func save(_ image: UIImage) async throws {
        let status = await authorizationStatus()
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoLibrarySaveError.saveFailed)
                }
            }
        }
    }

    private static func authorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch currentStatus {
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        default:
            return currentStatus
        }
    }
}
