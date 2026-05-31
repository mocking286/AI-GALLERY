import Foundation

enum ArtStyle: String, CaseIterable, Codable {
    case all
    case cinematic
    case generative
    case surreal
    case product
    case architecture

    static var galleryCases: [ArtStyle] {
        [.all, .cinematic, .generative, .surreal, .product, .architecture]
    }

    nonisolated var label: String {
        switch self {
        case .all: "全部"
        case .cinematic: "电影感"
        case .generative: "生成艺术"
        case .surreal: "超现实"
        case .product: "产品渲染"
        case .architecture: "空间建筑"
        }
    }

    nonisolated var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .cinematic: "movieclapper"
        case .generative: "point.3.connected.trianglepath.dotted"
        case .surreal: "moon.stars"
        case .product: "shippingbox"
        case .architecture: "building.columns"
        }
    }

    nonisolated var searchPrompt: String {
        switch self {
        case .all:
            "curated AI art, editorial visual community, refined composition, contemporary digital gallery"
        case .cinematic:
            "cinematic AI artwork, dramatic light, quiet narrative, premium editorial still"
        case .generative:
            "generative AI artwork, algorithmic forms, luminous systems, clean visual rhythm"
        case .surreal:
            "surreal AI artwork, dream architecture, impossible scale, poetic atmosphere"
        case .product:
            "AI product render, tactile industrial design, studio lighting, premium object study"
        case .architecture:
            "AI architecture visualization, spatial design, cultural building, natural light"
        }
    }

    nonisolated var previewImageURL: URL? {
        Artwork.domesticImageURL(seed: previewSeed, role: "topic")
    }

    nonisolated private var previewSeed: Int {
        switch self {
        case .all: 1101
        case .cinematic: 1203
        case .generative: 1307
        case .surreal: 1409
        case .product: 1511
        case .architecture: 1613
        }
    }
}

struct Artwork: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let style: ArtStyle
    let mood: String
    let prompt: String
    let imageURL: URL?
    let thumbnailURL: URL?
    let sourceName: String
    let sourceURL: URL?
    let creator: String
    let licenseNote: String
    let width: Double
    let height: Double
    let seed: Int

    var aspectRatio: Double {
        guard height > 0 else { return 0.78 }
        return width / height
    }

    var displayURL: URL? {
        thumbnailURL ?? imageURL
    }

    var baseLikeCount: Int {
        let titleScore = title.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 1000 }
        return 260 + abs((seed * 37 + titleScore * 11) % 18600)
    }
}

nonisolated extension Artwork {
    static func curatedFeed(
        style: ArtStyle = .all,
        query: String? = nil,
        page: Int = 0,
        limit: Int = 24,
        streamID: Int = 0
    ) -> [Artwork] {
        let review = ContentSafety.review(query ?? "")
        let safeQuery = review.isBlocked ? "" : review.sanitizedQuery
        let basePrompt = safeQuery.isEmpty ? style.searchPrompt : "\(safeQuery), \(style.searchPrompt)"
        let definitions = curatedDefinitions(for: style)
        let pageStart = max(0, page) * max(1, limit)
        let normalizedStreamID = max(0, streamID)

        return (0..<max(1, limit)).map { index in
            let streamIndex = pageStart + index
            let visualIndex = streamIndex + normalizedStreamID * 1_000
            let definition = definitions[visualIndex % definitions.count]
            let streamTitle = streamTitle(base: definition.title, index: visualIndex)
            let streamMood = streamMood(base: definition.mood, index: visualIndex)
            let streamPrompt = streamPrompt(base: definition.prompt, index: visualIndex)
            let size = streamSize(for: visualIndex, fallback: definition.size)
            let seed = definition.seed
                + stableOffset(from: safeQuery)
                + (visualIndex + 1) * 137
                + styleSeed(definition.style)
            let imageURL = domesticImageURL(seed: seed, role: definition.style.rawValue)

            return Artwork(
                id: "generated-\(style.rawValue)-\(seed)-\(visualIndex)-\(stableIDComponent(from: safeQuery))",
                title: safeQuery.isEmpty ? streamTitle : "\(streamTitle) · \(safeQuery)",
                style: definition.style,
                mood: streamMood,
                prompt: "\(streamPrompt), \(basePrompt), clean white gallery context, image-first editorial curation, \(ContentSafety.publicGallerySafetyPrompt)",
                imageURL: imageURL,
                thumbnailURL: imageURL,
                sourceName: "国内高速图片源",
                sourceURL: URL(string: "https://xxapi.cn/doc/wallpaper"),
                creator: "国内 CDN 图源",
                licenseNote: "图片经国内接口和 CDN 加载，用于视觉灵感展示",
                width: Double(size.width),
                height: Double(size.height),
                seed: seed
            )
        }
    }

    static func domesticImageURL(seed: Int, role: String) -> URL? {
        var components = URLComponents(string: "https://picsum.photos/seed/aigallery-\(role)-\(seed)/900/1200")
        components?.queryItems = [
            URLQueryItem(name: "grayscale", value: nil)
        ]
        return components?.url
    }

    static func engagementText(for count: Int) -> String {
        if count >= 10_000 {
            let value = Double(count) / 10_000
            return String(format: "%.1f万", value)
        }

        return "\(count)"
    }

    private static func curatedDefinitions(for style: ArtStyle) -> [CuratedArtworkDefinition] {
        let allDefinitions: [CuratedArtworkDefinition] = [
            .init(title: "银幕梦境", style: .cinematic, mood: "低饱和、叙事光、静默人物", prompt: "a cinematic AI scene with a solitary figure beside a reflective gallery window, soft rain, restrained colors", size: (900, 1240), seed: 2101),
            .init(title: "参数花园", style: .generative, mood: "有机曲线、粒子、发光结构", prompt: "a generative garden of luminous algorithmic petals, fine mesh structure, museum-grade digital art", size: (900, 1120), seed: 2203),
            .init(title: "漂浮档案", style: .surreal, mood: "超现实、透明、宁静", prompt: "floating translucent archives above a quiet interior sea, surreal scale, poetic light", size: (900, 1320), seed: 2309),
            .init(title: "柔性终端", style: .product, mood: "触感材料、微光、精密", prompt: "premium AI wearable product render, matte ceramic, glass sensor ring, refined studio light", size: (900, 1060), seed: 2411),
            .init(title: "云端剧场", style: .architecture, mood: "公共空间、晨光、层叠", prompt: "AI architecture visualization of a cloudlike cultural theater with terraces and daylight atrium", size: (900, 1180), seed: 2521),
            .init(title: "合成肖像", style: .cinematic, mood: "胶片颗粒、侧光、情绪", prompt: "editorial portrait study made with AI, cinematic side light, elegant minimal styling", size: (900, 1250), seed: 2633),
            .init(title: "城市折面", style: .architecture, mood: "几何、白昼、秩序", prompt: "folded city blocks generated by AI, precise geometry, human scale, clean daylight", size: (900, 1020), seed: 2741),
            .init(title: "频谱花瓶", style: .product, mood: "玻璃、虹彩、静物", prompt: "iridescent AI-designed glass vase object, restrained studio still life, soft shadows", size: (900, 1200), seed: 2851),
            .init(title: "数据潮汐", style: .generative, mood: "波形、蓝绿、动态", prompt: "data tide generative artwork, flowing signal bands, oceanic rhythm, crisp detail", size: (900, 1100), seed: 2963),
            .init(title: "无重力室", style: .surreal, mood: "梦境、室内、失重", prompt: "surreal room with gravity-free furniture and luminous paper screens, AI dream interior", size: (900, 1350), seed: 3079)
        ]

        guard style != .all else { return allDefinitions }
        let filtered = allDefinitions.filter { $0.style == style }
        return filtered.isEmpty ? allDefinitions : filtered + allDefinitions.filter { $0.style != style }.prefix(6)
    }

    private static func streamTitle(base: String, index: Int) -> String {
        let prefixes = ["薄雾", "镜面", "晨光", "夜行", "流银", "微光", "霜白", "星轨", "折光", "雾蓝", "静场", "远岸"]
        let subjects = ["庭院", "档案", "剧场", "终端", "温室", "界面", "回廊", "展台", "海面", "街角", "晶格", "天井"]
        let prefix = prefixes[(index + base.count) % prefixes.count]
        let subject = subjects[(index * 3 + base.count) % subjects.count]
        return "\(prefix)\(subject)"
    }

    private static func streamMood(base: String, index: Int) -> String {
        let first = ["克制", "通透", "低饱和", "清冷", "柔和", "高反差", "沉静", "明亮"]
        let second = ["构成", "光影", "材质", "空间", "粒子", "叙事", "轮廓", "秩序"]
        let third = ["留白", "层次", "节奏", "空气感", "微距", "纵深", "反射", "静物感"]
        return "\(first[index % first.count])、\(second[(index + 2) % second.count])、\(third[(index + 5) % third.count])"
    }

    private static func streamPrompt(base: String, index: Int) -> String {
        let modifiers = [
            "fresh AI visual feed, contemporary mobile gallery composition, polished editorial framing",
            "AI generated image study, clean composition, expressive but public-safe visual language",
            "high quality digital artwork, fast-loading image feed, refined color discipline",
            "mobile-first gallery artwork, balanced crop, strong focal point, elegant details",
            "curated AI inspiration image, modern lifestyle visual culture, natural light",
            "premium visual community post, crisp detail, calm background, collectible artwork"
        ]
        return "\(base), \(modifiers[index % modifiers.count])"
    }

    private static func streamSize(for index: Int, fallback: (width: Int, height: Int)) -> (width: Int, height: Int) {
        let sizes = [
            (900, 1180), (900, 1040), (900, 1280), (900, 960),
            (900, 1350), (900, 1120), (900, 1220), (900, 1000)
        ]
        return sizes.isEmpty ? fallback : sizes[index % sizes.count]
    }

    private static func styleSeed(_ style: ArtStyle) -> Int {
        switch style {
        case .all: 11
        case .cinematic: 23
        case .generative: 37
        case .surreal: 41
        case .product: 53
        case .architecture: 67
        }
    }

    private static func stableOffset(from query: String) -> Int {
        guard !query.isEmpty else { return 0 }
        return abs(query.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 997 })
    }

    private static func stableIDComponent(from query: String) -> String {
        guard !query.isEmpty else { return "default" }
        return query
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .prefix(18)
            .map(String.init)
            .joined()
    }
}

nonisolated private struct CuratedArtworkDefinition {
    let title: String
    let style: ArtStyle
    let mood: String
    let prompt: String
    let size: (width: Int, height: Int)
    let seed: Int
}
