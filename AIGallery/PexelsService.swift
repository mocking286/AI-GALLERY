import Foundation

/// Lightweight client for the public Pexels REST API.
///
/// Pexels provides a free, SFW, curated library of real photos and short videos.
/// Requests require an API key in the `Authorization` header. When no key is
/// configured the client throws `PexelsServiceError.missingAPIKey` so callers
/// can fall back to the bundled curated feed.
nonisolated struct PexelsService {
    enum PexelsServiceError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case requestFailed(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "未配置 Pexels API Key"
            case .invalidResponse:
                "Pexels 返回数据异常"
            case let .requestFailed(status):
                "Pexels 请求失败：HTTP \(status)"
            }
        }
    }

    private let apiKeyProvider: () -> String?
    private let session: URLSession
    private let videosBaseURL = URL(string: "https://api.pexels.com/videos")!
    private let photosBaseURL = URL(string: "https://api.pexels.com/v1")!

    init(
        apiKeyProvider: @escaping () -> String? = { AppConfig.pexelsAPIKey },
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    var hasAPIKey: Bool {
        apiKeyProvider() != nil
    }

    func fetchVideos(query: String?, page: Int, perPage: Int) async throws -> [PexelsVideo] {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var components: URLComponents
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "per_page", value: String(min(80, max(1, perPage))))
        ]

        if trimmed.isEmpty {
            components = URLComponents(url: videosBaseURL.appending(path: "popular"), resolvingAgainstBaseURL: false)!
        } else {
            components = URLComponents(url: videosBaseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
            items.append(URLQueryItem(name: "query", value: trimmed))
            items.append(URLQueryItem(name: "orientation", value: "portrait"))
        }
        components.queryItems = items

        let response: PexelsVideoResponse = try await send(url: components.url!)
        return response.videos
    }

    func fetchPhotos(query: String?, page: Int, perPage: Int) async throws -> [PexelsPhoto] {
        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var components: URLComponents
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "per_page", value: String(min(80, max(1, perPage))))
        ]

        if trimmed.isEmpty {
            components = URLComponents(url: photosBaseURL.appending(path: "curated"), resolvingAgainstBaseURL: false)!
        } else {
            components = URLComponents(url: photosBaseURL.appending(path: "search"), resolvingAgainstBaseURL: false)!
            items.append(URLQueryItem(name: "query", value: trimmed))
        }
        components.queryItems = items

        let response: PexelsPhotoResponse = try await send(url: components.url!)
        return response.photos
    }

    private func send<T: Decodable>(url: URL) async throws -> T {
        guard let apiKey = apiKeyProvider() else {
            throw PexelsServiceError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PexelsServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw PexelsServiceError.requestFailed(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PexelsServiceError.invalidResponse
        }
    }
}

// MARK: - Video models

nonisolated struct PexelsVideoResponse: Decodable {
    let videos: [PexelsVideo]
}

nonisolated struct PexelsVideo: Decodable {
    let id: Int
    let width: Int
    let height: Int
    let duration: Int
    let url: URL?
    let image: URL?
    let user: PexelsUser?
    let videoFiles: [PexelsVideoFile]

    enum CodingKeys: String, CodingKey {
        case id, width, height, duration, url, image, user
        case videoFiles = "video_files"
    }

    /// Picks an MP4 stream that plays smoothly on a phone: prefer ~720p, then
    /// the closest available height, avoiding oversized 4K files.
    ///
    /// Only MP4 files with a valid link are considered. If none are available
    /// this returns `nil` so the caller skips the clip rather than handing the
    /// player an incompatible format (e.g. WebM or an HLS playlist).
    var bestStreamURL: URL? {
        let mp4Files = videoFiles.filter { file in
            file.link != nil && (file.fileType ?? "").lowercased().contains("mp4")
        }
        guard !mp4Files.isEmpty else { return nil }

        let target = 720
        let best = mp4Files.min { lhs, rhs in
            abs((lhs.height ?? 0) - target) < abs((rhs.height ?? 0) - target)
        }
        return best?.link
    }
}

nonisolated struct PexelsVideoFile: Decodable {
    let id: Int?
    let quality: String?
    let fileType: String?
    let width: Int?
    let height: Int?
    let link: URL?

    enum CodingKeys: String, CodingKey {
        case id, quality, width, height, link
        case fileType = "file_type"
    }
}

nonisolated struct PexelsUser: Decodable {
    let id: Int?
    let name: String?
    let url: URL?
}

// MARK: - Photo models

nonisolated struct PexelsPhotoResponse: Decodable {
    let photos: [PexelsPhoto]
}

nonisolated struct PexelsPhoto: Decodable {
    let id: Int
    let width: Int
    let height: Int
    let url: URL?
    let photographer: String?
    let photographerURL: URL?
    let alt: String?
    let src: PexelsPhotoSource

    enum CodingKeys: String, CodingKey {
        case id, width, height, url, photographer, alt, src
        case photographerURL = "photographer_url"
    }
}

nonisolated struct PexelsPhotoSource: Decodable {
    let original: URL?
    let large2x: URL?
    let large: URL?
    let medium: URL?
    let portrait: URL?
    let tiny: URL?
}

// MARK: - Query keyword mapping

/// Translates the app's Chinese category / style labels into short English
/// keywords that produce strong Pexels search results.
nonisolated enum PexelsKeyword {
    private static let map: [String: String] = [
        // Video categories
        "电影短片": "cinematic",
        "AI 动画": "animation",
        "AI动画": "animation",
        "视觉设计": "graphic design",
        "空间影像": "architecture",
        "产品视频": "product",
        "生成实验": "abstract",
        // Art styles
        "全部": "",
        "电影感": "cinematic",
        "生成艺术": "abstract",
        "超现实": "surreal",
        "产品渲染": "product",
        "空间建筑": "architecture",
        // Common interest tags
        "建筑": "architecture",
        "城市": "city",
        "夜景": "night city",
        "光影": "light",
        "动画": "animation",
        "角色": "character",
        "叙事": "cinematic",
        "镜头": "cinematic",
        "产品": "product",
        "工业设计": "product design",
        "材质": "texture",
        "科技": "technology",
        "粒子": "particles",
        "循环": "loop motion",
        "抽象": "abstract",
        "胶片": "film",
        "设计": "design",
        "品牌": "branding",
        "版式": "typography",
        "海报": "poster",
        "室内": "interior",
        "空间": "interior",
        "生活方式": "lifestyle",
        "微距": "macro",
        "光泽": "glossy",
        "美食": "food",
        "探店": "restaurant",
        "节奏": "rhythm",
        "发布会": "technology",
        "屏幕": "screen",
        "演示": "presentation",
        "宠物": "pet",
        "日常": "daily life",
        "可爱": "cute",
        "治愈": "calm nature",
        "漫游": "walkthrough",
        "结构": "structure",
        "运动": "sports",
        "剪辑": "fast motion",
        "速度": "speed",
        "虚拟人": "portrait",
        "舞台": "stage",
        "灯光": "stage light",
        "演出": "performance",
        "转场": "city transition",
        "街景": "street",
        "旅行": "travel"
    ]

    /// Returns a Pexels-friendly query for the given (possibly Chinese) text.
    /// Unknown non-empty input is passed through unchanged so user-entered
    /// English terms still work.
    static func query(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let mapped = map[trimmed] {
            return mapped
        }
        // Try the first whitespace-separated token (e.g. category labels with spaces).
        if let firstToken = trimmed.split(whereSeparator: { $0.isWhitespace }).first,
           let mapped = map[String(firstToken)] {
            return mapped
        }
        return trimmed
    }
}
