import Foundation

enum AIVideoCategory: String, CaseIterable, Codable {
    case cinematic
    case animation
    case design
    case architecture
    case product
    case generative

    var label: String {
        switch self {
        case .cinematic: "电影短片"
        case .animation: "AI 动画"
        case .design: "视觉设计"
        case .architecture: "空间影像"
        case .product: "产品视频"
        case .generative: "生成实验"
        }
    }

    var symbol: String {
        switch self {
        case .cinematic: "movieclapper"
        case .animation: "play.square.stack"
        case .design: "sparkles"
        case .architecture: "building.columns"
        case .product: "shippingbox"
        case .generative: "point.3.connected.trianglepath.dotted"
        }
    }
}

struct AIVideo: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let category: AIVideoCategory
    let tags: [String]
    let prompt: String
    let videoURL: URL
    let coverURL: URL?
    let sourceName: String
    let sourceURL: URL?
    let creator: String
    let licenseNote: String
    let durationSeconds: Int
    let matchScore: Int
    let seed: Int

    var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

nonisolated private struct AIVideoSourceAsset {
    let url: URL
    let coverURL: URL?
    let sourceName: String
    let sourceURL: URL?
    let licenseNote: String
}

nonisolated extension AIVideo {
    static func curatedFeed(
        topic: String? = nil,
        page: Int = 0,
        limit: Int = 12,
        streamID: Int = 0,
        interests: [String: Int] = [:]
    ) -> [AIVideo] {
        let review = ContentSafety.review(topic ?? "")
        let safeTopic = review.isBlocked ? "" : review.sanitizedQuery
        let definitions = rankedDefinitions(for: interests)
        let pageStart = max(0, page) * max(1, limit)
        let normalizedStreamID = max(0, streamID)

        return (0..<max(1, limit)).map { index in
            let streamIndex = pageStart + index
            let visualIndex = streamIndex + normalizedStreamID * 500
            let definitionOffset = interests.isEmpty ? normalizedStreamID : 0
            let definition = definitions[(streamIndex + definitionOffset) % definitions.count]
            let seed = definition.seed + visualIndex * 149 + stableOffset(from: safeTopic)
            let score = min(99, 68 + interestScore(for: definition, interests: interests) * 3 + (visualIndex % 13))
            let title = safeTopic.isEmpty
                ? streamTitle(base: definition.title, index: visualIndex)
                : "\(streamTitle(base: definition.title, index: visualIndex)) · \(safeTopic)"
            let sourceAsset = sourceAsset(for: definition, streamIndex: streamIndex, streamID: normalizedStreamID)

            return AIVideo(
                id: "hot-video-\(definition.category.rawValue)-\(seed)-\(visualIndex)-\(stableIDComponent(from: safeTopic))",
                title: title,
                subtitle: definition.subtitle,
                category: definition.category,
                tags: Array((definition.tags + derivedTags(for: safeTopic)).prefix(5)),
                prompt: "\(definition.prompt), \(safeTopic.isEmpty ? "AI short video recommendation" : safeTopic), safe public creative feed",
                videoURL: sourceAsset.url,
                coverURL: sourceAsset.coverURL ?? Artwork.domesticImageURL(seed: seed, role: "ai-video-cover"),
                sourceName: sourceAsset.sourceName,
                sourceURL: sourceAsset.sourceURL,
                creator: definition.creator,
                licenseNote: sourceAsset.licenseNote,
                durationSeconds: definition.duration + visualIndex % 18,
                matchScore: score,
                seed: seed
            )
        }
    }

    private static func rankedDefinitions(for interests: [String: Int]) -> [AIVideoDefinition] {
        let definitions = curatedDefinitions
        guard !interests.isEmpty else { return definitions }

        return definitions.sorted {
            let leftScore = interestScore(for: $0, interests: interests)
            let rightScore = interestScore(for: $1, interests: interests)
            if leftScore == rightScore {
                return $0.seed < $1.seed
            }
            return leftScore > rightScore
        }
    }

    private static func interestScore(for definition: AIVideoDefinition, interests: [String: Int]) -> Int {
        let tagScore = definition.tags.reduce(0) { $0 + (interests[$1] ?? 0) }
        return tagScore + (interests[definition.category.rawValue] ?? 0)
    }

    private static func sourceAsset(for definition: AIVideoDefinition, streamIndex: Int, streamID: Int) -> AIVideoSourceAsset {
        let localAssets = localVideoAssets
        if !localAssets.isEmpty, streamIndex < localAssets.count * 2 || streamIndex.isMultiple(of: 5) {
            return localAssets[streamIndex % localAssets.count]
        }

        let remoteAssets = remoteVideoAssets
        let assets = remoteAssets.isEmpty ? videoAssets : remoteAssets
        let assetIndex = abs(definition.seed + streamIndex * 7 + streamID * 13) % assets.count
        return assets[assetIndex]
    }

    private static func streamTitle(base: String, index: Int) -> String {
        let prefixes = ["热榜", "连刷", "新作", "快剪", "飙升", "焦点", "上新", "精选", "趋势", "循环"]
        return "\(prefixes[index % prefixes.count])\(base)"
    }

    private static func derivedTags(for topic: String) -> [String] {
        guard !topic.isEmpty else { return [] }
        return topic
            .split { $0.isWhitespace || $0 == "," || $0 == "，" }
            .prefix(2)
            .map(String.init)
    }

    private static func stableOffset(from topic: String) -> Int {
        guard !topic.isEmpty else { return 0 }
        return abs(topic.unicodeScalars.reduce(0) { ($0 * 29 + Int($1.value)) % 1_291 })
    }

    private static func stableIDComponent(from topic: String) -> String {
        guard !topic.isEmpty else { return "default" }
        return topic
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .prefix(18)
            .map(String.init)
            .joined()
    }

    private static var curatedDefinitions: [AIVideoDefinition] {
        [
            .init(title: "城市夜景热榜", subtitle: "高频浏览建筑与空间内容时优先推送", category: .architecture, tags: ["建筑", "城市", "夜景", "光影"], prompt: "AI generated city montage with spatial rhythm and clean architectural lighting", creator: "AIGC 建筑频道", duration: 31, seed: 8101),
            .init(title: "国风动画连刷", subtitle: "喜欢角色、动画与叙事镜头的用户会看到更多", category: .animation, tags: ["动画", "角色", "叙事", "镜头"], prompt: "AI character motion short, expressive animation, cinematic framing", creator: "Motion Lab", duration: 24, seed: 8203),
            .init(title: "产品开箱快剪", subtitle: "根据产品渲染、工业设计互动提升权重", category: .product, tags: ["产品", "工业设计", "材质", "科技"], prompt: "AI product concept video, premium material, precise studio turntable motion", creator: "Object Studio", duration: 28, seed: 8311),
            .init(title: "抽象循环实验", subtitle: "生成艺术、粒子、图形类兴趣会持续加权", category: .generative, tags: ["生成艺术", "粒子", "循环", "抽象"], prompt: "generative AI loop, particles and clean algorithmic motion", creator: "Generative Room", duration: 22, seed: 8423),
            .init(title: "电影感短片", subtitle: "偏好电影感作品时推送更多叙事短片", category: .cinematic, tags: ["电影感", "叙事", "光影", "胶片"], prompt: "cinematic AI short, restrained color and dramatic light", creator: "Frame Archive", duration: 35, seed: 8521),
            .init(title: "视觉海报动效", subtitle: "平面视觉、海报、品牌动态内容会被推荐", category: .design, tags: ["设计", "品牌", "版式", "海报"], prompt: "AI visual design reel, typography motion, gallery-grade composition", creator: "Design Signal", duration: 26, seed: 8627),
            .init(title: "室内漫游", subtitle: "空间、家居、超现实内容混合推荐", category: .architecture, tags: ["室内", "空间", "超现实", "生活方式"], prompt: "dreamlike AI interior video, natural light and impossible scale", creator: "Interior Futures", duration: 29, seed: 8731),
            .init(title: "材质特写", subtitle: "收藏或点赞产品材质图后更容易出现", category: .product, tags: ["材质", "产品", "微距", "光泽"], prompt: "macro AI material test, polished surfaces and tactile detail", creator: "Material Lab", duration: 23, seed: 8849),
            .init(title: "美食探店切片", subtitle: "更适合快速浏览的节奏感画面", category: .cinematic, tags: ["美食", "探店", "切片", "节奏"], prompt: "fast-paced food short video, warm light, handheld rhythm, social feed style", creator: "Flavor Cut", duration: 19, seed: 8951),
            .init(title: "科技发布会", subtitle: "科技发布节奏、屏幕演示和产品亮点", category: .product, tags: ["科技", "发布会", "屏幕", "演示"], prompt: "tech launch short video, product reveal, LED stage, polished motion graphics", creator: "Launch Board", duration: 27, seed: 9067),
            .init(title: "宠物日常", subtitle: "轻松、可爱、停留时长高的内容", category: .animation, tags: ["宠物", "日常", "可爱", "治愈"], prompt: "cute pet lifestyle reel, cozy motion, soft highlight and friendly pacing", creator: "Pet Loop", duration: 21, seed: 9173),
            .init(title: "建筑漫游", subtitle: "适合喜欢空间、结构与城市镜头的用户", category: .architecture, tags: ["建筑", "漫游", "结构", "城市"], prompt: "architectural walkthrough short video, strong lines, airy depth, clean transitions", creator: "Structure Atlas", duration: 33, seed: 9281),
            .init(title: "运动节奏", subtitle: "强调速度、剪辑和强烈节拍", category: .cinematic, tags: ["运动", "节奏", "剪辑", "速度"], prompt: "sports montage short video, energetic cuts, dynamic motion blur, punchy edit", creator: "Pulse Edit", duration: 18, seed: 9397),
            .init(title: "虚拟人舞台", subtitle: "更偏演出、灯光与虚拟角色表现", category: .generative, tags: ["虚拟人", "舞台", "灯光", "演出"], prompt: "virtual human stage performance, dramatic lighting, elegant motion, audience energy", creator: "Stage Render", duration: 32, seed: 9511),
            .init(title: "城市转场", subtitle: "旅行、街景和镜头切换适合反复刷新", category: .cinematic, tags: ["城市", "转场", "街景", "旅行"], prompt: "city travel transition reel, quick cuts, sunrise to neon, social video pacing", creator: "Transit Frame", duration: 20, seed: 9623)
        ]
    }

    private static var videoAssets: [AIVideoSourceAsset] {
        localVideoAssets + remoteVideoAssets
    }

    private static var localVideoAssets: [AIVideoSourceAsset] {
        let bundledItems = [
            (
                fileName: "aigallery-local-motion-1",
                sourceName: "本地精选短片 · 内置素材 01"
            ),
            (
                fileName: "aigallery-local-motion-2",
                sourceName: "本地精选短片 · 内置素材 02"
            )
        ]

        return bundledItems.compactMap { item in
            guard let videoURL = Bundle.main.url(forResource: item.fileName, withExtension: "mp4") else {
                return nil
            }

            return AIVideoSourceAsset(
                url: videoURL,
                coverURL: Bundle.main.url(forResource: item.fileName, withExtension: "jpg"),
                sourceName: item.sourceName,
                sourceURL: nil,
                licenseNote: "内置本地演示素材，离线可播放"
            )
        }
    }

    private static var remoteVideoAssets: [AIVideoSourceAsset] {
        [
            .init(
                url: URL(string: "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4")!,
                coverURL: nil,
                sourceName: "视频号热榜风格 · 公开素材",
                sourceURL: URL(string: "https://developer.mozilla.org/"),
                licenseNote: "CC0 公开视频源，可用于展示与测试"
            ),
            .init(
                url: URL(string: "https://samplelib.com/lib/preview/mp4/sample-5s.mp4")!,
                coverURL: nil,
                sourceName: "小红书灵感风格 · 公开素材",
                sourceURL: URL(string: "https://samplelib.com/"),
                licenseNote: "公开预览视频源，可用于展示与测试"
            ),
            .init(
                url: URL(string: "https://samplelib.com/lib/preview/mp4/sample-10s.mp4")!,
                coverURL: nil,
                sourceName: "B站热榜风格 · 公开素材",
                sourceURL: URL(string: "https://samplelib.com/"),
                licenseNote: "公开预览视频源，可用于展示与测试"
            ),
            .init(
                url: URL(string: "https://samplelib.com/lib/preview/mp4/sample-15s.mp4")!,
                coverURL: nil,
                sourceName: "抖音热榜风格 · 公开素材",
                sourceURL: URL(string: "https://samplelib.com/"),
                licenseNote: "公开预览视频源，可用于展示与测试"
            ),
            .init(
                url: URL(string: "https://media.w3.org/2010/05/bunny/trailer.mp4")!,
                coverURL: nil,
                sourceName: "快手热榜风格 · 公共预告片",
                sourceURL: URL(string: "https://www.w3.org/"),
                licenseNote: "公开视频预告片，适合短视频展示"
            ),
            .init(
                url: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
                coverURL: nil,
                sourceName: "视频号热榜风格 · 公共预告片",
                sourceURL: URL(string: "https://www.w3.org/"),
                licenseNote: "公开视频预告片，适合短视频展示"
            )
        ]
    }
}

nonisolated private struct AIVideoDefinition {
    let title: String
    let subtitle: String
    let category: AIVideoCategory
    let tags: [String]
    let prompt: String
    let creator: String
    let duration: Int
    let seed: Int
}
