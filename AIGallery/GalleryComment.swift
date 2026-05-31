import Foundation

nonisolated struct GalleryComment: Identifiable, Hashable, Codable {
    let id: String
    let artworkID: String
    let authorName: String
    let body: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        artworkID: String,
        authorName: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.artworkID = artworkID
        self.authorName = authorName
        self.body = body
        self.createdAt = createdAt
    }
}
