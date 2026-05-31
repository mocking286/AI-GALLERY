import Foundation

/// Central place to resolve runtime configuration such as third-party API keys.
///
/// Keys are looked up in this order:
/// 1. Process environment (handy for the simulator / Xcode scheme).
/// 2. `Info.plist` entry (works on a real device where env vars are unavailable).
nonisolated enum AppConfig {
    static var pexelsAPIKey: String? {
        resolve(environmentKey: "PEXELS_API_KEY", infoPlistKey: "PexelsAPIKey")
    }

    static var hasPexelsKey: Bool {
        pexelsAPIKey != nil
    }

    static var dashScopeAPIKey: String? {
        resolve(environmentKey: "DASHSCOPE_API_KEY", infoPlistKey: "DashScopeAPIKey")
    }

    static var hasDashScopeKey: Bool {
        dashScopeAPIKey != nil
    }

    private static func resolve(environmentKey: String, infoPlistKey: String) -> String? {
        if let fromEnvironment = sanitized(ProcessInfo.processInfo.environment[environmentKey]) {
            return fromEnvironment
        }

        if let fromInfoPlist = sanitized(Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String) {
            return fromInfoPlist
        }

        return nil
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        // Ignore unexpanded build-setting placeholders such as "$(PEXELS_API_KEY)".
        if trimmed.hasPrefix("$(") || trimmed == "YOUR_API_KEY" {
            return nil
        }

        return trimmed
    }
}
