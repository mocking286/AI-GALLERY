import AVFoundation
import Combine
import SwiftUI

@MainActor
final class VideoThumbnailLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private static let cache = NSCache<NSURL, UIImage>()
    private var task: Task<Void, Never>?
    private var currentURL: URL?

    func load(videoURL: URL?) {
        guard currentURL != videoURL else { return }
        currentURL = videoURL
        image = nil
        task?.cancel()

        guard let videoURL else {
            isLoading = false
            return
        }

        if let cached = Self.cache.object(forKey: videoURL as NSURL) {
            image = cached
            isLoading = false
            return
        }

        isLoading = true
        task = Task {
            do {
                let thumbnail = try await Self.generateThumbnail(from: videoURL)
                guard !Task.isCancelled else { return }
                Self.cache.setObject(thumbnail, forKey: videoURL as NSURL)
                image = thumbnail
            } catch {
                if !Task.isCancelled {
                    image = nil
                }
            }

            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    func cancel() {
        task?.cancel()
        isLoading = false
    }

    private static func generateThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1080, height: 1080)

        let time = CMTime(seconds: 1.2, preferredTimescale: 600)
        let cgImage = try await generator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }
}

struct VideoThumbnailView: View {
    let videoURL: URL
    let fallbackURL: URL?
    let title: String
    @StateObject private var videoLoader = VideoThumbnailLoader()
    @StateObject private var fallbackLoader = CachedImageLoader()

    var body: some View {
        Group {
            if let image = videoLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            } else {
                GalleryImageContent(loader: fallbackLoader, title: title)
            }
        }
        .background(Color.galleryImagePlaceholder)
        .clipped()
        .accessibilityLabel(title)
        .task(id: videoURL) {
            videoLoader.load(videoURL: videoURL)
            fallbackLoader.load(fallbackURL)
        }
        .onDisappear {
            videoLoader.cancel()
            fallbackLoader.cancel()
        }
    }
}
