import SwiftUI

struct ArtworkCardView<Destination: View>: View {
    @EnvironmentObject private var library: GalleryLibrary
    let artwork: Artwork
    let isFavorite: Bool
    let rank: Int
    private let destination: Destination

    init(artwork: Artwork, isFavorite: Bool, rank: Int = 0, @ViewBuilder destination: () -> Destination) {
        self.artwork = artwork
        self.isFavorite = isFavorite
        self.rank = rank
        self.destination = destination()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            NavigationLink {
                destination
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    AdaptiveGalleryImage(url: artwork.displayURL, title: artwork.title, fallbackAspectRatio: masonryAspectRatio)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(artwork.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("artwork-title-\(rank)")
                }
            }
            .buttonStyle(.plain)

            cardActions
                .padding(.horizontal, 2)
                .padding(.bottom, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.clear)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(artwork.title)，\(artwork.style.label)，\(isFavorite ? "已收藏" : "未收藏")")
    }

    private var masonryAspectRatio: CGFloat {
        let baseRatio = CGFloat(artwork.aspectRatio)
        guard baseRatio > 0 else { return 0.78 }
        let variation: CGFloat = rank.isMultiple(of: 3) ? 0.08 : (rank % 3 == 1 ? -0.06 : 0.03)
        return min(max(baseRatio + variation, 0.66), 1.08)
    }

    private var cardActions: some View {
        HStack(spacing: 8) {
            Label(artwork.style.label, systemImage: artwork.style.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                withAnimation(.snappy) {
                    library.toggleLike(artwork)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: library.isLiked(artwork) ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.caption2.weight(.bold))
                    Text(library.likeCountText(for: artwork))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(minWidth: 40, minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(library.isLiked(artwork) ? .primary : .secondary)
            .accessibilityLabel(library.isLiked(artwork) ? "取消点赞" : "点赞作品")

            Button {
                withAnimation(.snappy) {
                    library.toggleFavorite(artwork)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isFavorite ? Color.galleryRed : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "取消收藏" : "收藏作品")
        }
    }
}

struct FeaturedArtworkCard: View {
    let artwork: Artwork
    let isFavorite: Bool

    var body: some View {
        GalleryRemoteImage(url: artwork.imageURL, title: artwork.title)
            .aspectRatio(1.2, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.18), .black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("AI 视觉精选")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.2), in: Capsule())

                    Text(artwork.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(artwork.mood)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                }
                .padding(18)
            }
            .overlay(alignment: .topTrailing) {
                FavoriteBadge(isFavorite: isFavorite)
                    .padding(12)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("精选作品，\(artwork.title)")
    }
}

struct TopicChipView: View {
    let style: ArtStyle
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GalleryRemoteImage(url: style.previewImageURL, title: style.label)
                .frame(width: 128, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.03), .black.opacity(isSelected ? 0.72 : 0.56)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            Label(style.label, systemImage: style.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
        }
        .accessibilityLabel(style.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GalleryRemoteImage: View {
    let url: URL?
    let title: String
    @StateObject private var loader = CachedImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            } else {
                placeholder
                    .overlay(alignment: .bottomLeading) {
                        if loader.isLoading {
                            Text("国内图源加载中")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(10)
                        }
                    }
            }
        }
        .background(Color.galleryImagePlaceholder)
        .clipped()
        .accessibilityLabel(title)
        .task(id: url) {
            loader.load(url)
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.galleryImagePlaceholder, Color.galleryWarmGray, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct AdaptiveGalleryImage: View {
    let url: URL?
    let title: String
    let fallbackAspectRatio: CGFloat
    @StateObject private var loader = CachedImageLoader()

    var body: some View {
        GalleryImageContent(loader: loader, title: title)
            .aspectRatio(loader.imageAspectRatio ?? fallbackAspectRatio, contentMode: .fit)
            .background(Color.galleryImagePlaceholder)
            .clipped()
            .accessibilityLabel(title)
            .task(id: url) {
                loader.load(url)
            }
            .onDisappear {
                loader.cancel()
            }
    }
}

struct GalleryImageContent: View {
    @ObservedObject var loader: CachedImageLoader
    let title: String

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            } else {
                placeholder
                    .overlay(alignment: .bottomLeading) {
                        if loader.isLoading {
                            Text("国内图源加载中")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(10)
                        }
                    }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.galleryImagePlaceholder, Color.galleryWarmGray, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FavoriteBadge: View {
    let isFavorite: Bool

    var body: some View {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
            .font(.caption.weight(.bold))
            .foregroundStyle(isFavorite ? Color.galleryRed : .white)
            .frame(width: 30, height: 30)
            .background(.black.opacity(0.32), in: Circle())
    }
}
