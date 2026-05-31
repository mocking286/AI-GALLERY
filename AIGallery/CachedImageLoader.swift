import Combine
import SwiftUI

@MainActor
final class CachedImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var imageAspectRatio: CGFloat?
    @Published private(set) var isLoading = false

    private static let imageCache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 80 * 1024 * 1024,
            diskCapacity: 280 * 1024 * 1024
        )
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    private static let fallbackImageURL = URL(string: "https://imgapi.cn/api.php?fl=fengjing&gs=images")

    private var task: Task<Void, Never>?
    private var currentURL: URL?

    func load(_ url: URL?) {
        guard currentURL != url else { return }
        currentURL = url
        image = nil
        imageAspectRatio = nil
        task?.cancel()

        guard let url else {
            isLoading = false
            return
        }

        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            image = cached
            imageAspectRatio = Self.aspectRatio(for: cached)
            isLoading = false
            return
        }

        isLoading = true
        task = Task {
            do {
                let loadedImage = try await Self.fetchImage(from: url)
                Self.imageCache.setObject(loadedImage, forKey: url as NSURL)
                image = loadedImage
                imageAspectRatio = Self.aspectRatio(for: loadedImage)
            } catch {
                guard !Task.isCancelled else { return }

                if let fallbackURL = Self.fallbackImageURL,
                   let fallbackImage = try? await Self.fetchImage(from: fallbackURL) {
                    Self.imageCache.setObject(fallbackImage, forKey: url as NSURL)
                    image = fallbackImage
                    imageAspectRatio = Self.aspectRatio(for: fallbackImage)
                } else {
                    image = nil
                    imageAspectRatio = nil
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

    static func warm(_ urls: [URL?]) {
        let normalizedURLs = urls.compactMap(\.self).prefix(8)
        for url in normalizedURLs where imageCache.object(forKey: url as NSURL) == nil {
            Task(priority: .utility) {
                if let image = try? await fetchImage(from: url) {
                    imageCache.setObject(image, forKey: url as NSURL)
                }
            }
        }
    }

    static func image(for url: URL?) async throws -> UIImage {
        guard let url else { throw PhotoLibrarySaveError.imageUnavailable }

        if let cached = imageCache.object(forKey: url as NSURL) {
            return cached
        }

        do {
            let image = try await fetchImage(from: url)
            imageCache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            if let fallbackImageURL,
               let fallbackImage = try? await fetchImage(from: fallbackImageURL) {
                imageCache.setObject(fallbackImage, forKey: url as NSURL)
                return fallbackImage
            }
            throw PhotoLibrarySaveError.imageUnavailable
        }
    }

    private static func fetchImage(from url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 4

        let (data, response) = try await session.data(for: request)
        guard !Task.isCancelled,
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }

        return image
    }

    private static func aspectRatio(for image: UIImage) -> CGFloat? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }
}
