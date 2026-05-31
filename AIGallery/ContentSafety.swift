import Foundation

nonisolated enum ContentSafety {
    struct Review: Equatable {
        let sanitizedQuery: String
        let didFilter: Bool
        let isBlocked: Bool
    }

    private static let maximumQueryLength = 48
    private static let maximumPromptLength = 800
    private static let maximumCommentLength = 180

    private static let blockedTerms = [
        "porn", "porno", "sex", "sexual", "nude", "nudity", "nsfw", "erotic",
        "gore", "blood", "bloody", "suicide", "kill", "murder", "terrorist",
        "nazi", "racist", "hate symbol", "drug abuse", "child porn", "loli",
        "色情", "裸露", "裸体", "性暗示", "血腥", "自杀", "谋杀", "恐怖主义",
        "纳粹", "种族仇恨", "毒品", "儿童色情", "未成年裸"
    ]

    static func review(_ rawQuery: String) -> Review {
        reviewText(rawQuery, maximumLength: maximumQueryLength, allowsPublicPunctuation: false)
    }

    static func reviewPrompt(_ rawText: String) -> Review {
        reviewText(rawText, maximumLength: maximumPromptLength, allowsPublicPunctuation: true)
    }

    static func reviewComment(_ rawText: String) -> Review {
        reviewText(rawText, maximumLength: maximumCommentLength, allowsPublicPunctuation: true)
    }

    private static func reviewText(
        _ rawQuery: String,
        maximumLength: Int,
        allowsPublicPunctuation: Bool
    ) -> Review {
        let normalized = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !normalized.isEmpty else {
            return Review(sanitizedQuery: "", didFilter: false, isBlocked: false)
        }

        let lowercased = normalized.lowercased()
        if blockedTerms.contains(where: { lowercased.contains($0) }) {
            return Review(sanitizedQuery: "", didFilter: true, isBlocked: true)
        }

        let allowedScalars = normalized.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet.whitespaces.contains(scalar)
                || scalar == "-"
                || scalar == "_"
                || (allowsPublicPunctuation && publicCommentPunctuation.contains(scalar))
        }

        let sanitized = String(String.UnicodeScalarView(allowedScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(maximumLength)

        let sanitizedQuery = String(sanitized)
        return Review(
            sanitizedQuery: sanitizedQuery,
            didFilter: sanitizedQuery != normalized,
            isBlocked: false
        )
    }

    private static let publicCommentPunctuation = CharacterSet(charactersIn: "，。！？、：；,.!?:;()（）《》“”\"' ")

    static var publicGallerySafetyPrompt: String {
        "safe for all audiences, suitable for App Store public gallery, no nudity, no sexual content, no gore, no graphic violence, no hate symbols, no minors, no celebrity likeness, no text, no watermark"
    }
}
