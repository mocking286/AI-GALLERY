import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: GalleryLibrary
    @State private var selectedTab: GalleryTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .environmentObject(library)
                .tabItem {
                    Label("发现", systemImage: "house.fill")
                }
                .tag(GalleryTab.discover)

            FeaturedListView()
                .environmentObject(library)
                .tabItem {
                    Label("短视频", systemImage: "play.square.stack.fill")
                }
                .tag(GalleryTab.featured)

            ImageGenerationView()
                .tabItem {
                    Label("文生图", systemImage: "wand.and.stars.inverse")
                }
                .tag(GalleryTab.generate)

            FavoritesView()
                .environmentObject(library)
                .tabItem {
                    Label("收藏", systemImage: "heart.fill")
                }
                .tag(GalleryTab.favorites)

            ProfileView()
                .environmentObject(library)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(GalleryTab.profile)
        }
        .tint(.galleryAccentStrong)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
        .task {
            await library.loadInitialFeedIfNeeded()
        }
    }
}

private enum GalleryTab {
    case discover
    case featured
    case generate
    case favorites
    case profile
}

private struct DiscoverView: View {
    @EnvironmentObject private var library: GalleryLibrary
    @State private var selectedStyle: ArtStyle = .all
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    topBar
                    searchPanel
                    topicSection
                    discoverSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 168)
            }
            .background(Color.galleryBackground.ignoresSafeArea())
            .refreshable {
                await library.refresh(style: selectedStyle, query: searchText)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Button {
                    Task {
                        await library.refresh(style: selectedStyle, query: searchText)
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .background(Color.galleryWarmGray, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("在线搜索")

                Spacer()

                VStack(spacing: 2) {
                    Text("发现")
                        .font(.system(size: 19, weight: .bold))
                    Text(library.isLoading ? "同步中" : library.sourceSummary)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {} label: {
                    Image(systemName: library.isLoading ? "arrow.triangle.2.circlepath" : "bell")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .background(Color.galleryWarmGray, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(library.isLoading ? "正在同步" : "通知")
            }

            Text("AI 视觉灵感流")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("今日灵感、热门风格、实时图集")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("搜索感兴趣的 AI 图片", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("discover-search-field")
                .onSubmit {
                    Task {
                        await library.refresh(style: selectedStyle, query: searchText)
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task {
                        await library.refresh(style: selectedStyle, query: nil)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }

            Button {
                Task {
                    await library.refresh(style: selectedStyle, query: searchText)
                }
            } label: {
                Text("搜索")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("discover-search-button")
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.galleryWarmGray, lineWidth: 1)
        }
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "热门标签", action: "换一批") {
                Task {
                    await library.refresh(style: selectedStyle, query: searchText)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ArtStyle.galleryCases, id: \.self) { style in
                        Button {
                            withAnimation(.snappy) {
                                selectedStyle = style
                            }
                            Task {
                                await library.refresh(style: style, query: searchText)
                            }
                        } label: {
                            TopicChipView(style: style, isSelected: selectedStyle == style)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "发现作品", action: nil, actionHandler: nil)
                .accessibilityElement(children: .combine)
                .accessibilityValue("作品数量 \(library.artworks.count)")
                .accessibilityIdentifier("discover-artwork-count")

            MasonryArtworkGrid(artworks: library.artworks)
                .environmentObject(library)
                .overlay {
                    if library.artworks.isEmpty {
                        ContentUnavailableView("没有匹配作品", systemImage: "magnifyingglass", description: Text("换一个关键词或标签。"))
                            .padding(.top, 48)
                    }
                }
        }
    }

    private func sectionHeader(title: String, action: String?, actionHandler: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Spacer()
            if let action, let actionHandler {
                Button(action) {
                    actionHandler()
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MasonryArtworkGrid: View {
    @EnvironmentObject private var library: GalleryLibrary
    let artworks: [Artwork]

    private var leftColumn: [(offset: Int, element: Artwork)] {
        Array(artworks.enumerated()).filter { $0.offset.isMultiple(of: 2) }
    }

    private var rightColumn: [(offset: Int, element: Artwork)] {
        Array(artworks.enumerated()).filter { !$0.offset.isMultiple(of: 2) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                masonryColumn(leftColumn)
                masonryColumn(rightColumn)
            }

            loadMoreSentinel
        }
    }

    private var loadMoreSentinel: some View {
        Group {
            if library.canLoadMore {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        Task {
                            await library.loadMoreIfNeeded(current: artworks.last)
                        }
                    }
            }
        }
    }

    private func masonryColumn(_ artworks: [(offset: Int, element: Artwork)]) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(artworks, id: \.element.id) { item in
                let index = item.offset
                let artwork = item.element
                ArtworkCardView(
                    artwork: artwork,
                    isFavorite: library.isFavorite(artwork),
                    rank: index
                ) {
                    ArtworkDetailView(artwork: artwork)
                        .environmentObject(library)
                }
                .onAppear {
                    if index >= self.artworks.count - 6 {
                        Task {
                            await library.loadMoreIfNeeded(current: artwork)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct FeaturedListView: View {
    @EnvironmentObject private var library: GalleryLibrary

    var body: some View {
        AIVideoFeedView()
            .environmentObject(library)
    }
}

private struct FavoritesView: View {
    @EnvironmentObject private var library: GalleryLibrary

    private var favorites: [Artwork] {
        library.favoriteArtworks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if favorites.isEmpty {
                    ContentUnavailableView("还没有收藏", systemImage: "heart", description: Text("在作品详情页点亮心形即可收藏。"))
                        .padding(.top, 80)
                } else {
                    MasonryArtworkGrid(artworks: favorites)
                        .environmentObject(library)
                        .padding(18)
                }
            }
            .background(Color.galleryBackground.ignoresSafeArea())
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var library: GalleryLibrary
    @EnvironmentObject private var session: UserSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                        Text("AI")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Gallery")
                            .font(.title2.weight(.bold))
                        Text("发现 / 展示 / 收集")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    metricTile(value: "\(library.artworks.count)", label: "在线作品")
                    metricTile(value: "\(library.favoriteIDs.count)", label: "收藏")
                    metricTile(value: library.sourceSummary, label: "图源")
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("账号")
                        .font(.headline)
                    Text("已绑定 \(session.maskedPhoneNumber)，收藏和点赞会保存在本机。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    session.signOut()
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(18)
            .background(Color.galleryBackground.ignoresSafeArea())
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func metricTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    ContentView()
        .environmentObject(GalleryLibrary())
        .environmentObject(UserSession())
}
