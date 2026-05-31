import SwiftUI

extension Color {
    static let galleryBackground = Color(red: 0.985, green: 0.982, blue: 0.974)
    static let galleryWarmGray = Color(red: 0.935, green: 0.925, blue: 0.905)
    static let galleryImagePlaceholder = Color(red: 0.905, green: 0.91, blue: 0.90)
    static let galleryTextMuted = Color(red: 0.38, green: 0.38, blue: 0.36)
    static let galleryRed = Color(red: 0.88, green: 0.10, blue: 0.16)
    static let galleryAccent = Color(red: 0.97, green: 0.38, blue: 0.18)
    static let galleryAccentStrong = Color(red: 1.0, green: 0.48, blue: 0.22)
    static let galleryTabInactive = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.80, alpha: 1)
                : UIColor(red: 0.40, green: 0.40, blue: 0.38, alpha: 1)
        }
    )
}
