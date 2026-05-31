import Foundation

nonisolated final class GalleryPersistenceStore {
    static let standard = GalleryPersistenceStore()

    private let defaults: UserDefaults
    private let keyPrefix: String

    init(defaults: UserDefaults = .standard, keyPrefix: String = "AIGallery") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func loadFavoriteArtworks() -> [Artwork] {
        load([Artwork].self, key: "favoriteArtworks") ?? []
    }

    func saveFavoriteArtworks(_ artworks: [Artwork]) {
        save(artworks, key: "favoriteArtworks")
    }

    func loadLikedIDs() -> Set<String> {
        Set(load([String].self, key: "likedIDs") ?? [])
    }

    func saveLikedIDs(_ ids: Set<String>) {
        save(Array(ids), key: "likedIDs")
    }

    func loadCommentsByArtworkID() -> [String: [GalleryComment]] {
        load([String: [GalleryComment]].self, key: "commentsByArtworkID") ?? [:]
    }

    func saveCommentsByArtworkID(_ commentsByArtworkID: [String: [GalleryComment]]) {
        save(commentsByArtworkID, key: "commentsByArtworkID")
    }

    func loadBoundPhoneNumber() -> String? {
        defaults.string(forKey: storageKey("boundPhoneNumber"))
    }

    func saveBoundPhoneNumber(_ phoneNumber: String) {
        defaults.set(phoneNumber, forKey: storageKey("boundPhoneNumber"))
    }

    func clearBoundPhoneNumber() {
        defaults.removeObject(forKey: storageKey("boundPhoneNumber"))
    }

    private func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = defaults.data(forKey: storageKey(key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey(key))
    }

    private func storageKey(_ key: String) -> String {
        "\(keyPrefix).\(key)"
    }
}
