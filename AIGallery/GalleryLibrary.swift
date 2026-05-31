import Combine
import Foundation

@MainActor
final class GalleryLibrary: ObservableObject {
    private static let pageSize = 24
    private static let videoPageSize = 10

    @Published private(set) var artworks: [Artwork]
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var favoriteArtworks: [Artwork]
    @Published private(set) var likedIDs: Set<String>
    @Published private(set) var commentsByArtworkID: [String: [GalleryComment]]
    @Published private(set) var aiVideos: [AIVideo]
    @Published private(set) var likedVideoIDs: Set<String>
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isVideoLoading = false
    @Published private(set) var isVideoLoadingMore = false
    @Published private(set) var sourceSummary = AppConfig.hasPexelsKey ? "Pexels 实时图源" : "内置精选图源"
    @Published private(set) var videoSourceSummary = AppConfig.hasPexelsKey ? "Pexels 实时短视频流" : "内置精选短视频流"
    @Published private(set) var lastQuery = "AI 视觉精选"
    @Published private(set) var canLoadMore = true
    @Published private(set) var canLoadMoreVideos = true
    @Published private(set) var videoStreamVersion = 0

    private let feedService: GalleryFeedService
    private let videoFeedService: AIVideoFeedService
    private let persistence: GalleryPersistenceStore
    private var didLoadInitialFeed = false
    private var didLoadInitialVideoFeed = false
    private var currentStyle: ArtStyle = .all
    private var currentQuery = ""
    private var currentVideoTopic = ""
    private var nextPage = 0
    private var nextVideoPage = 0
    private var streamID = 0
    private var videoStreamID = 0
    private var videoInterestWeights: [String: Int] = [:]

    init(
        artworks: [Artwork] = Artwork.curatedFeed(),
        aiVideos: [AIVideo] = AIVideo.curatedFeed(),
        favoriteArtworks: [Artwork]? = nil,
        likedIDs: Set<String>? = nil,
        likedVideoIDs: Set<String>? = nil,
        commentsByArtworkID: [String: [GalleryComment]]? = nil,
        feedService: GalleryFeedService = GalleryFeedService(),
        videoFeedService: AIVideoFeedService = AIVideoFeedService(),
        persistence: GalleryPersistenceStore = .standard
    ) {
        let storedFavorites = favoriteArtworks ?? persistence.loadFavoriteArtworks()
        self.artworks = artworks
        self.aiVideos = aiVideos
        self.favoriteArtworks = storedFavorites
        self.favoriteIDs = Set(storedFavorites.map(\.id))
        self.likedIDs = likedIDs ?? persistence.loadLikedIDs()
        self.likedVideoIDs = likedVideoIDs ?? []
        self.commentsByArtworkID = commentsByArtworkID ?? persistence.loadCommentsByArtworkID()
        self.feedService = feedService
        self.videoFeedService = videoFeedService
        self.persistence = persistence
    }

    func loadInitialFeedIfNeeded() async {
        guard !didLoadInitialFeed else { return }
        didLoadInitialFeed = true
        await refresh(style: .all, query: nil)
    }

    func loadInitialVideoFeedIfNeeded() async {
        guard !didLoadInitialVideoFeed else { return }
        didLoadInitialVideoFeed = true
        await refreshVideos(topic: nil)
    }

    func refresh(style: ArtStyle, query: String?) async {
        streamID += 1
        let review = ContentSafety.review(query ?? "")
        let effectiveQuery = review.isBlocked ? "" : review.sanitizedQuery
        let fallback = Artwork.curatedFeed(
            style: style,
            query: effectiveQuery,
            page: 0,
            limit: Self.pageSize,
            streamID: streamID
        )
        currentStyle = style
        currentQuery = effectiveQuery
        nextPage = 1
        canLoadMore = true
        artworks = fallback
        lastQuery = effectiveQuery.isEmpty ? style.label : effectiveQuery

        if review.isBlocked {
            isLoading = false
            isLoadingMore = false
            canLoadMore = false
            sourceSummary = "已过滤不适合公开展示的关键词"
            return
        }

        isLoading = true
        sourceSummary = review.didFilter ? "已清理搜索词并加载实时图源" : "正在加载实时图源"

        let remote = await feedService.searchArtworks(
            style: style,
            query: effectiveQuery,
            page: 0,
            limit: Self.pageSize,
            streamID: streamID
        )
        if !Task.isCancelled, !remote.isEmpty {
            artworks = remote
            warmUpcomingImages(from: remote)
            sourceSummary = review.didFilter ? "已清理搜索词并加载实时图源" : "持续更新中"
        } else if !Task.isCancelled {
            sourceSummary = AppConfig.hasPexelsKey ? "Pexels 实时图源" : "内置精选图源"
        }

        if !Task.isCancelled {
            isLoading = false
        }
    }

    func loadMoreIfNeeded(current artwork: Artwork?) async {
        guard canLoadMore,
              let artwork,
              shouldLoadMore(current: artwork),
              !isLoading,
              !isLoadingMore else {
            return
        }

        isLoadingMore = true
        sourceSummary = "正在补充新作品"

        let pageToLoad = nextPage
        let nextItems = await feedService.searchArtworks(
            style: currentStyle,
            query: currentQuery,
            page: pageToLoad,
            limit: Self.pageSize,
            streamID: streamID
        )

        if !Task.isCancelled, !nextItems.isEmpty {
            let existingIDs = Set(artworks.map(\.id))
            let uniqueItems = nextItems.filter { !existingIDs.contains($0.id) }
            artworks.append(contentsOf: uniqueItems)
            nextPage = pageToLoad + 1
            warmUpcomingImages(from: uniqueItems)
            canLoadMore = uniqueItems.count == Self.pageSize
        } else if !Task.isCancelled {
            canLoadMore = false
        }

        if !Task.isCancelled {
            isLoadingMore = false
            sourceSummary = "持续更新中"
        }
    }

    func refreshVideos(topic: String?) async {
        videoStreamID += 1
        let review = ContentSafety.review(topic ?? "")
        let effectiveTopic = review.isBlocked ? "" : review.sanitizedQuery
        currentVideoTopic = effectiveTopic
        nextVideoPage = 1
        canLoadMoreVideos = true
        isVideoLoading = true
        videoSourceSummary = review.didFilter ? "已清理搜索词，加载实时短视频流" : "正在加载实时短视频流"

        if review.isBlocked {
            aiVideos = []
            isVideoLoading = false
            canLoadMoreVideos = false
            videoSourceSummary = "已过滤不适合公开展示的关键词"
            return
        }

        let videos = await videoFeedService.fetchVideos(
            topic: effectiveTopic,
            page: 0,
            limit: Self.videoPageSize,
            streamID: videoStreamID,
            interests: videoInterestWeights
        )

        if !Task.isCancelled {
            aiVideos = videos
            videoStreamVersion = videoStreamID
            videoSourceSummary = effectiveTopic.isEmpty ? "实时短视频流 · 个性化推荐中" : "正在推送：\(effectiveTopic)"
            isVideoLoading = false
        }
    }

    func loadMoreVideosIfNeeded(current video: AIVideo?) async {
        guard canLoadMoreVideos,
              let video,
              shouldLoadMoreVideo(current: video),
              !isVideoLoading,
              !isVideoLoadingMore else {
            return
        }

        isVideoLoadingMore = true
        videoSourceSummary = "正在分析偏好并补充短视频"

        let pageToLoad = nextVideoPage
        let nextItems = await videoFeedService.fetchVideos(
            topic: currentVideoTopic,
            page: pageToLoad,
            limit: Self.videoPageSize,
            streamID: videoStreamID,
            interests: videoInterestWeights
        )

        if !Task.isCancelled, !nextItems.isEmpty {
            let existingIDs = Set(aiVideos.map(\.id))
            let uniqueItems = nextItems.filter { !existingIDs.contains($0.id) }
            aiVideos.append(contentsOf: uniqueItems)
            nextVideoPage = pageToLoad + 1
            canLoadMoreVideos = uniqueItems.count == Self.videoPageSize
        } else if !Task.isCancelled {
            canLoadMoreVideos = false
        }

        if !Task.isCancelled {
            isVideoLoadingMore = false
            videoSourceSummary = "实时短视频流 · 个性化推荐中"
        }
    }

    func artworks(for ids: Set<String>) -> [Artwork] {
        let visibleArtworks = artworks.filter { ids.contains($0.id) }
        let visibleIDs = Set(visibleArtworks.map(\.id))
        let savedArtworks = favoriteArtworks.filter {
            ids.contains($0.id) && !visibleIDs.contains($0.id)
        }

        return savedArtworks + visibleArtworks
    }

    func isFavorite(_ artwork: Artwork) -> Bool {
        favoriteIDs.contains(artwork.id)
    }

    func toggleFavorite(_ artwork: Artwork) {
        if favoriteIDs.contains(artwork.id) {
            favoriteIDs.remove(artwork.id)
            favoriteArtworks.removeAll { $0.id == artwork.id }
        } else {
            favoriteIDs.insert(artwork.id)
            favoriteArtworks.removeAll { $0.id == artwork.id }
            favoriteArtworks.insert(artwork, at: 0)
        }
        persistence.saveFavoriteArtworks(favoriteArtworks)
    }

    func isLiked(_ artwork: Artwork) -> Bool {
        likedIDs.contains(artwork.id)
    }

    func likeCount(for artwork: Artwork) -> Int {
        artwork.baseLikeCount + (isLiked(artwork) ? 1 : 0)
    }

    func likeCountText(for artwork: Artwork) -> String {
        Artwork.engagementText(for: likeCount(for: artwork))
    }

    func comments(for artwork: Artwork) -> [GalleryComment] {
        (commentsByArtworkID[artwork.id] ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    func commentCount(for artwork: Artwork) -> Int {
        commentsByArtworkID[artwork.id]?.count ?? 0
    }

    func addComment(for artwork: Artwork, body: String, authorName: String = "我") throws {
        let review = ContentSafety.reviewComment(body)
        guard !review.isBlocked, !review.sanitizedQuery.isEmpty else {
            throw CommentError.invalidContent
        }

        let comment = GalleryComment(
            artworkID: artwork.id,
            authorName: authorName,
            body: review.sanitizedQuery
        )
        var comments = commentsByArtworkID[artwork.id] ?? []
        comments.insert(comment, at: 0)
        commentsByArtworkID[artwork.id] = Array(comments.prefix(80))
        persistence.saveCommentsByArtworkID(commentsByArtworkID)
    }

    func toggleLike(_ artwork: Artwork) {
        if likedIDs.contains(artwork.id) {
            likedIDs.remove(artwork.id)
        } else {
            likedIDs.insert(artwork.id)
        }
        persistence.saveLikedIDs(likedIDs)
    }

    func isVideoLiked(_ video: AIVideo) -> Bool {
        likedVideoIDs.contains(video.id)
    }

    func toggleVideoLike(_ video: AIVideo) {
        if likedVideoIDs.contains(video.id) {
            likedVideoIDs.remove(video.id)
            recordVideoEngagement(video, action: .dislike)
        } else {
            likedVideoIDs.insert(video.id)
            recordVideoEngagement(video, action: .like)
        }
    }

    func recordVideoEngagement(_ video: AIVideo, action: VideoEngagementAction) {
        let weight: Int
        switch action {
        case .impression:
            weight = 1
        case .open:
            weight = 3
        case .watch:
            weight = 5
        case .like:
            weight = 10
        case .dislike:
            weight = -6
        }

        videoInterestWeights[video.category.rawValue, default: 0] = max(0, videoInterestWeights[video.category.rawValue, default: 0] + weight)
        for tag in video.tags {
            videoInterestWeights[tag, default: 0] = max(0, videoInterestWeights[tag, default: 0] + weight)
        }
    }

    var videoInterestSummary: String {
        let top = videoInterestWeights
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(2)
            .map(\.key)

        return top.isEmpty ? "正在学习偏好" : "偏好 \(top.joined(separator: " / "))"
    }

    private func shouldLoadMore(current artwork: Artwork) -> Bool {
        guard let currentIndex = artworks.firstIndex(where: { $0.id == artwork.id }) else {
            return false
        }

        return currentIndex >= max(artworks.count - 6, 0)
    }

    private func shouldLoadMoreVideo(current video: AIVideo) -> Bool {
        guard let currentIndex = aiVideos.firstIndex(where: { $0.id == video.id }) else {
            return false
        }

        return currentIndex >= max(aiVideos.count - 6, 0)
    }

    private func warmUpcomingImages(from artworks: [Artwork]) {
        CachedImageLoader.warm(artworks.prefix(8).map(\.displayURL))
    }
}

enum VideoEngagementAction {
    case impression
    case open
    case watch
    case like
    case dislike
}

nonisolated enum CommentError: LocalizedError {
    case invalidContent

    var errorDescription: String? {
        "评论内容不适合公开讨论，请调整后再发布"
    }
}
