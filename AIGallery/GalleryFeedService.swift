import Foundation

/// Provides the discover-feed artworks.
///
/// When a Pexels API key is configured this loads real, SFW photos from Pexels
/// (curated feed for "全部" with no query, search otherwise). Without a key, or
/// on any network failure, it falls back to the bundled curated definitions.
nonisolated struct GalleryFeedService {
    private let pexels: PexelsService

    init(pexels: PexelsService = PexelsService()) {
        self.pexels = pexels
    }

    func searchArtworks(style: ArtStyle, query: String, page: Int, limit: Int, streamID: Int) async -> [Artwork] {
        guard pexels.hasAPIKey else {
            return curatedFallback(style: style, query: query, page: page, limit: limit, streamID: streamID)
        }

        let effectiveQuery = Self.effectiveQuery(style: style, query: query)

        do {
            let photos = try await pexels.fetchPhotos(
                query: effectiveQuery.isEmpty ? nil : effectiveQuery,
                page: page + 1,
                perPage: limit
            )

            let mapped = photos.enumerated().compactMap { offset, photo in
                Self.makeArtwork(
                    from: photo,
                    style: style,
                    query: query,
                    streamIndex: page * limit + offset
                )
            }

            if mapped.isEmpty {
                return curatedFallback(style: style, query: query, page: page, limit: limit, streamID: streamID)
            }
            return mapped
        } catch {
            return curatedFallback(style: style, query: query, page: page, limit: limit, streamID: streamID)
        }
    }

    private func curatedFallback(style: ArtStyle, query: String, page: Int, limit: Int, streamID: Int) -> [Artwork] {
        Artwork.curatedFeed(style: style, query: query, page: page, limit: limit, streamID: streamID)
    }

    // MARK: - Mapping

    private static func effectiveQuery(style: ArtStyle, query: String) -> String {
        let queryKeyword = query.isEmpty ? "" : PexelsKeyword.query(for: query)
        let styleKeyword = PexelsKeyword.query(for: style.label)

        if queryKeyword.isEmpty { return styleKeyword }
        if styleKeyword.isEmpty { return queryKeyword }
        return "\(queryKeyword) \(styleKeyword)"
    }

    private static let titlePrefixes = ["薄雾", "镜面", "晨光", "夜行", "流银", "微光", "霜白", "星轨", "折光", "雾蓝", "静场", "远岸"]
    private static let titleSubjects = ["庭院", "档案", "剧场", "终端", "温室", "界面", "回廊", "展台", "海面", "街角", "晶格", "天井"]

    static func makeArtwork(from photo: PexelsPhoto, style: ArtStyle, query: String, streamIndex: Int) -> Artwork? {
        guard let imageURL = photo.src.large2x ?? photo.src.large ?? photo.src.original ?? photo.src.portrait else {
            return nil
        }
        let thumbnailURL = photo.src.large ?? photo.src.medium ?? photo.src.portrait ?? imageURL

        let prefix = titlePrefixes[abs(streamIndex) % titlePrefixes.count]
        let subject = titleSubjects[abs(streamIndex * 3 + photo.id) % titleSubjects.count]
        let baseTitle = "\(prefix)\(subject)"
        let title = query.isEmpty ? baseTitle : "\(baseTitle) · \(query)"

        let altText = photo.alt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mood = (altText?.isEmpty == false) ? altText! : "真实摄影、自然光、Pexels 精选"
        let photographer = photo.photographer?.trimmingCharacters(in: .whitespacesAndNewlines)
        let creator = (photographer?.isEmpty == false) ? photographer! : "Pexels 摄影师"

        return Artwork(
            id: "pexels-photo-\(photo.id)-\(streamIndex)",
            title: title,
            style: style == .all ? inferStyle(index: streamIndex) : style,
            mood: mood,
            prompt: "\(mood), real photography from Pexels, \(ContentSafety.publicGallerySafetyPrompt)",
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            sourceName: "Pexels 精选",
            sourceURL: photo.url,
            creator: creator,
            licenseNote: "Pexels 免费授权图片，可自由用于视觉灵感展示",
            width: Double(max(1, photo.width)),
            height: Double(max(1, photo.height)),
            seed: photo.id
        )
    }

    private static func inferStyle(index: Int) -> ArtStyle {
        let styles: [ArtStyle] = [.cinematic, .generative, .surreal, .product, .architecture]
        return styles[abs(index) % styles.count]
    }
}
