import AVFoundation
import AVKit
import SwiftUI

struct AIVideoFeedView: View {
    @EnvironmentObject private var library: GalleryLibrary
    @State private var topicText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    videoHeader
                    videoSearchBar
                    interestStrip

                    ForEach(Array(library.aiVideos.enumerated()), id: \.element.id) { item in
                        let index = item.offset
                        let video = item.element
                        NavigationLink {
                            AIVideoDetailView(video: video)
                                .environmentObject(library)
                        } label: {
                            AIVideoCardView(video: video, isLiked: library.isVideoLiked(video), rank: index)
                                .environmentObject(library)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            library.recordVideoEngagement(video, action: .open)
                        })
                        .onAppear {
                            library.recordVideoEngagement(video, action: .impression)
                            if index >= library.aiVideos.count - 6 {
                                Task {
                                    await library.loadMoreVideosIfNeeded(current: video)
                                }
                            }
                        }
                    }

                    videoLoadMoreSentinel
                }
                .padding(18)
                .padding(.bottom, 112)
            }
            .background(Color.galleryBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                videoFeedStatusPill
            }
            .refreshable {
                await library.refreshVideos(topic: topicText)
            }
            .navigationTitle("AI 短视频")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await library.loadInitialVideoFeedIfNeeded()
            }
        }
    }

    private var videoHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI 短视频")
                        .font(.system(size: 28, weight: .bold))
                    Text(library.videoSourceSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task {
                        await library.refreshVideos(topic: topicText)
                    }
                } label: {
                    Image(systemName: library.isVideoLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(Color.galleryWarmGray, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新短视频")
                .accessibilityIdentifier("video-refresh-button")
                .accessibilityValue("视频流 \(library.videoStreamVersion)")
            }

            Text("根据你打开、点赞和停留的题材，在本机调整后续推送顺序。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(videoFeedStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var videoFeedStatusText: String {
        "视频流 \(library.videoStreamVersion) · 视频数量 \(library.aiVideos.count)"
    }

    private var videoFeedStatusPill: some View {
        Text(videoFeedStatusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.galleryWarmGray.opacity(0.8), lineWidth: 1)
            }
            .padding(.bottom, 8)
            .accessibilityIdentifier("ai-video-count")
            .accessibilityValue("视频流 \(library.videoStreamVersion) 视频数量 \(library.aiVideos.count)")
    }

    private var videoSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索想看的 AI 短视频", text: $topicText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .accessibilityIdentifier("video-search-field")
                .onSubmit {
                    isSearchFocused = false
                    Task {
                        await library.refreshVideos(topic: topicText)
                    }
                }

            Button {
                isSearchFocused = false
                Task {
                    await library.refreshVideos(topic: topicText)
                }
            } label: {
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.galleryAccentStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索短视频")
            .accessibilityIdentifier("video-search-button")
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.galleryWarmGray, lineWidth: 1)
        }
    }

    private var interestStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                Label(library.videoInterestSummary, systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.galleryWarmGray, in: Capsule())

                ForEach(AIVideoCategory.allCases, id: \.self) { category in
                    Button {
                        topicText = category.label
                        Task {
                            await library.refreshVideos(topic: category.label)
                        }
                    } label: {
                        Label(category.label, systemImage: category.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var videoLoadMoreSentinel: some View {
        Group {
            if library.canLoadMoreVideos {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .onAppear {
                        Task {
                            await library.loadMoreVideosIfNeeded(current: library.aiVideos.last)
                        }
                    }
            }
        }
    }
}

private struct AIVideoCardView: View {
    @EnvironmentObject private var library: GalleryLibrary
    let video: AIVideo
    let isLiked: Bool
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack(alignment: .bottomLeading) {
                VideoThumbnailView(videoURL: video.videoURL, fallbackURL: video.coverURL, title: video.title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 430)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                LinearGradient(
                    colors: [.black.opacity(0.04), .black.opacity(0.3), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                        Text(video.durationText)
                            .font(.caption.weight(.bold))
                        Label(video.sourceName, systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                        Text("\(video.matchScore)% 匹配")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.32), in: Capsule())

                    Text(video.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .accessibilityIdentifier("video-title-\(rank)")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(video.title)

                    Text(video.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(2)

                    tagRow
                }
                .padding(16)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            HStack(spacing: 10) {
                Label(video.category.label, systemImage: video.category.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label("连续流", systemImage: "arrow.down.forward.and.arrow.up.backward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        library.toggleVideoLike(video)
                    }
                } label: {
                    Label(isLiked ? "已喜欢" : "喜欢", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(isLiked ? .white : .primary)
                        .background(isLiked ? Color.galleryAccentStrong : Color.galleryWarmGray, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "取消喜欢短视频" : "喜欢短视频")
            }
        }
        .padding(10)
        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AI 短视频，\(video.title)")
    }

    private var tagRow: some View {
        HStack(spacing: 7) {
            ForEach(video.tags.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
            }
        }
    }
}

private struct AIVideoDetailView: View {
    @EnvironmentObject private var library: GalleryLibrary
    let video: AIVideo
    @State private var player: AVPlayer?
    @State private var playbackError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    VideoPlayer(player: player)
                        .frame(height: 420)
                        .background(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if let playbackError {
                        VStack(spacing: 10) {
                            Image(systemName: "play.slash.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Text("视频暂时无法播放")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(playbackError)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.88))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.68))
                    }
                }
                .onAppear {
                    preparePlayer()
                }
                .onDisappear {
                    player?.pause()
                    player = nil
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(video.sourceName, systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(video.title)
                        .font(.system(size: 30, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(video.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.snappy) {
                                library.toggleVideoLike(video)
                            }
                        } label: {
                            Label(library.isVideoLiked(video) ? "已喜欢" : "喜欢", systemImage: library.isVideoLiked(video) ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.galleryAccentStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await library.refreshVideos(topic: video.tags.first ?? video.category.label)
                            }
                        } label: {
                            Label("类似", systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    detailSection(title: "推荐原因", text: "\(video.matchScore)% 匹配你的近期偏好：\(video.tags.joined(separator: "、"))")
                    detailSection(title: "提示词", text: video.prompt)
                    detailSection(title: "来源", text: "\(video.sourceName) · \(video.licenseNote)")
                    detailSection(title: "创作者", text: video.creator)
                }
            }
            .padding(18)
            .padding(.bottom, 48)
        }
        .background(Color.galleryBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func preparePlayer() {
        playbackError = nil
        let player = AVPlayer(url: video.videoURL)
        self.player = player
        library.recordVideoEngagement(video, action: .watch)

        Task {
            let asset = AVURLAsset(url: video.videoURL)

            do {
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    await MainActor.run {
                        playbackError = "当前素材不可播放，请下拉刷新后重试。"
                    }
                    return
                }

                await MainActor.run {
                    player.play()
                }
            } catch {
                await MainActor.run {
                    playbackError = "视频源加载失败，请刷新推荐流。"
                }
            }
        }
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
