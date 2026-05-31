import SwiftUI

struct ArtworkDetailView: View {
    @EnvironmentObject private var library: GalleryLibrary
    let artwork: Artwork
    @State private var commentText = ""
    @State private var messageText = ""
    @State private var isSavingImage = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AdaptiveGalleryImage(
                        url: artwork.displayURL,
                        title: artwork.title,
                        fallbackAspectRatio: CGFloat(artwork.aspectRatio)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(artwork.title)
                                    .font(.system(size: 29, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Label(artwork.style.label, systemImage: artwork.style.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Button {
                                withAnimation(.snappy) {
                                    library.toggleFavorite(artwork)
                                }
                            } label: {
                                Image(systemName: library.isFavorite(artwork) ? "heart.fill" : "heart")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(library.isFavorite(artwork) ? Color.galleryRed : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(Color.galleryWarmGray, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(library.isFavorite(artwork) ? "取消收藏" : "收藏作品")
                        }

                        Text(artwork.mood)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        DisclosureGroup {
                            detailBodyText(artwork.prompt)
                                .padding(.top, 6)
                        } label: {
                            Text("提示词")
                                .font(.headline)
                        }
                        .tint(.primary)
                        .padding(.vertical, 4)

                        detailSection(title: "来源", text: "\(artwork.sourceName) · \(artwork.licenseNote)")
                        detailSection(title: "创作者", text: artwork.creator)
                        commentsSection
                    }
                }
                .padding(18)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            bottomActionBar
        }
        .background(Color.galleryBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var bottomActionBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy) {
                    library.toggleLike(artwork)
                }
            } label: {
                Label(library.isLiked(artwork) ? "已点赞" : "点赞", systemImage: library.isLiked(artwork) ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                saveToPhotos()
            } label: {
                Label(isSavingImage ? "保存中" : "下载", systemImage: isSavingImage ? "arrow.triangle.2.circlepath" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSavingImage)

            Button {
                withAnimation(.snappy) {
                    library.toggleFavorite(artwork)
                }
            } label: {
                Label(library.isFavorite(artwork) ? "已收藏" : "收藏", systemImage: library.isFavorite(artwork) ? "heart.fill" : "heart")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.galleryWarmGray.opacity(0.7))
                .frame(height: 1)
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("讨论")
                    .font(.headline)
                Text("\(library.commentCount(for: artwork))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.galleryWarmGray, in: Capsule())
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("说说你对这张作品的看法", text: $commentText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.galleryWarmGray, lineWidth: 1)
                    }

                Button {
                    publishComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("发布评论")
            }

            if !messageText.isEmpty {
                Text(messageText)
                    .font(.footnote)
                    .foregroundStyle(messageText.contains("失败") || messageText.contains("不适合") || messageText.contains("需要") ? Color.galleryRed : .secondary)
            }

            let comments = library.comments(for: artwork)
            if comments.isEmpty {
                Text("还没有讨论，发布第一条评论。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private func detailSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            detailBodyText(text)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailBodyText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func publishComment() {
        do {
            try library.addComment(for: artwork, body: commentText)
            commentText = ""
            messageText = "评论已发布"
        } catch {
            messageText = error.localizedDescription
        }
    }

    private func saveToPhotos() {
        guard !isSavingImage else { return }
        isSavingImage = true
        messageText = "正在保存到相册"

        Task {
            do {
                let image = try await CachedImageLoader.image(for: artwork.displayURL)
                try await PhotoLibrarySaver.save(image)
                messageText = "已保存到系统相册"
            } catch {
                messageText = error.localizedDescription
            }
            isSavingImage = false
        }
    }
}

private struct CommentRow: View {
    let comment: GalleryComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.galleryWarmGray)
                Text(String(comment.authorName.prefix(1)))
                    .font(.caption.weight(.bold))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(comment.authorName)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(comment.body)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
