import Foundation

/// Provides the short-video feed.
///
/// When a Pexels API key is configured this streams real, SFW short videos from
/// the Pexels library (popular feed by default, topic search when a topic is
/// supplied). If the key is missing or the network call fails, it falls back to
/// the bundled curated feed so the app always shows something playable.
nonisolated struct AIVideoFeedService {
    private let pexels: PexelsService

    init(pexels: PexelsService = PexelsService()) {
        self.pexels = pexels
    }

    func fetchVideos(
        topic: String,
        page: Int,
        limit: Int,
        streamID: Int,
        interests: [String: Int]
    ) async -> [AIVideo] {
        guard pexels.hasAPIKey else {
            return curatedFallback(topic: topic, page: page, limit: limit, streamID: streamID, interests: interests)
        }

        let effectiveTopic = topic.isEmpty ? topInterestKeyword(from: interests) : topic
        let query = PexelsKeyword.query(for: effectiveTopic)

        do {
            let videos = try await pexels.fetchVideos(
                query: query.isEmpty ? nil : query,
                page: page + 1,
                perPage: limit
            )

            let mapped = videos.enumerated().compactMap { offset, video in
                Self.makeVideo(
                    from: video,
                    topic: topic,
                    keyword: query,
                    streamIndex: page * limit + offset,
                    interests: interests
                )
            }

            if mapped.isEmpty {
                return curatedFallback(topic: topic, page: page, limit: limit, streamID: streamID, interests: interests)
            }
            return mapped
        } catch {
            return curatedFallback(topic: topic, page: page, limit: limit, streamID: streamID, interests: interests)
        }
    }

    private func curatedFallback(
        topic: String,
        page: Int,
        limit: Int,
        streamID: Int,
        interests: [String: Int]
    ) -> [AIVideo] {
        AIVideo.curatedFeed(
            topic: topic,
            page: page,
            limit: limit,
            streamID: streamID,
            interests: interests
        )
    }

    private func topInterestKeyword(from interests: [String: Int]) -> String {
        interests
            .filter { $0.value > 0 }
            .max { lhs, rhs in
                lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
            }?
            .key ?? ""
    }

    // MARK: - Mapping

    private static let titlePrefixes = ["热榜", "连刷", "新作", "快剪", "飙升", "焦点", "上新", "精选", "趋势", "循环"]

    static func makeVideo(
        from video: PexelsVideo,
        topic: String,
        keyword: String,
        streamIndex: Int,
        interests: [String: Int]
    ) -> AIVideo? {
        guard let streamURL = video.bestStreamURL else { return nil }

        let category = inferCategory(keyword: keyword, index: streamIndex)
        let creator = video.user?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let creatorName = (creator?.isEmpty == false ? creator! : "Pexels 创作者")
        let prefix = titlePrefixes[abs(streamIndex) % titlePrefixes.count]
        let baseLabel = topic.isEmpty ? category.label : topic
        let title = "\(prefix)\(baseLabel)"

        let tags = buildTags(topic: topic, category: category)
        let score = min(99, 70 + interestScore(for: category, tags: tags, interests: interests) * 2 + abs(video.id) % 12)

        return AIVideo(
            id: "pexels-\(video.id)-\(streamIndex)",
            title: title,
            subtitle: "\(creatorName) · Pexels 实时短视频流",
            category: category,
            tags: tags,
            prompt: topic.isEmpty
                ? "Real short video from Pexels, \(keyword.isEmpty ? "popular feed" : keyword), safe public creative stream"
                : "Real short video from Pexels matching \(topic), safe public creative stream",
            videoURL: streamURL,
            coverURL: video.image,
            sourceName: topic.isEmpty ? "Pexels 热榜短视频" : "Pexels · \(topic)",
            sourceURL: video.url,
            creator: creatorName,
            licenseNote: "Pexels 免费授权，可自由用于展示与测试",
            durationSeconds: max(1, video.duration),
            matchScore: score,
            seed: video.id
        )
    }

    private static func buildTags(topic: String, category: AIVideoCategory) -> [String] {
        var tags: [String] = []
        let topicTokens = topic
            .split { $0.isWhitespace || $0 == "," || $0 == "，" }
            .prefix(2)
            .map(String.init)
        tags.append(contentsOf: topicTokens)
        tags.append(category.label)
        tags.append("Pexels")
        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted && !$0.isEmpty }
    }

    private static func interestScore(for category: AIVideoCategory, tags: [String], interests: [String: Int]) -> Int {
        let tagScore = tags.reduce(0) { $0 + (interests[$1] ?? 0) }
        return tagScore + (interests[category.rawValue] ?? 0)
    }

    private static func inferCategory(keyword: String, index: Int) -> AIVideoCategory {
        let lowered = keyword.lowercased()
        let table: [(needles: [String], category: AIVideoCategory)] = [
            (["animation", "character", "cute", "pet"], .animation),
            (["architecture", "interior", "structure", "walkthrough", "city", "night"], .architecture),
            (["product", "technology", "screen", "presentation", "texture", "glossy", "macro"], .product),
            (["abstract", "particles", "loop", "surreal", "stage", "performance"], .generative),
            (["design", "typography", "poster", "branding"], .design),
            (["cinematic", "film", "street", "travel", "sports", "speed", "rhythm"], .cinematic)
        ]

        for entry in table where entry.needles.contains(where: { lowered.contains($0) }) {
            return entry.category
        }

        let all = AIVideoCategory.allCases
        return all[abs(index) % all.count]
    }
}
