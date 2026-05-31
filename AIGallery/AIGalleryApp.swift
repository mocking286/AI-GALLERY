import SwiftUI

@main
struct AIGalleryApp: App {
    @StateObject private var library = GalleryLibrary()
    @StateObject private var session = UserSession()

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 80 * 1024 * 1024,
            diskCapacity: 280 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(library)
                .environmentObject(session)
                .preferredColorScheme(.light)
        }
    }
}
