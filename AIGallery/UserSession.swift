import Foundation
import Combine

@MainActor
final class UserSession: ObservableObject {
    enum LoginError: LocalizedError, Equatable {
        case invalidPhoneNumber
        case codeNotRequested
        case phoneNumberChanged
        case codeExpired
        case codeMismatch

        var errorDescription: String? {
            switch self {
            case .invalidPhoneNumber:
                "请输入 11 位中国大陆手机号"
            case .codeNotRequested:
                "请先获取验证码"
            case .phoneNumberChanged:
                "手机号与验证码不匹配"
            case .codeExpired:
                "验证码已过期，请重新获取"
            case .codeMismatch:
                "验证码不正确"
            }
        }
    }

    @Published private(set) var boundPhoneNumber: String?
    @Published private(set) var pendingPhoneNumber: String?
    @Published private(set) var verificationExpiresAt: Date?
    @Published private(set) var developmentVerificationCode: String?
    @Published private(set) var statusMessage = ""

    private let persistence: GalleryPersistenceStore
    private let now: () -> Date
    private let codeGenerator: () -> String
    private var pendingCode = ""

    init(
        persistence: GalleryPersistenceStore = .standard,
        now: @escaping () -> Date = Date.init,
        codeGenerator: @escaping () -> String = UserSession.generateVerificationCode
    ) {
        self.persistence = persistence
        self.now = now
        self.codeGenerator = codeGenerator
        boundPhoneNumber = persistence.loadBoundPhoneNumber()
    }

    var isAuthenticated: Bool {
        boundPhoneNumber != nil
    }

    var maskedPhoneNumber: String {
        guard let boundPhoneNumber else { return "未绑定" }
        return Self.maskPhoneNumber(boundPhoneNumber)
    }

    var pendingMaskedPhoneNumber: String {
        guard let pendingPhoneNumber else { return "" }
        return Self.maskPhoneNumber(pendingPhoneNumber)
    }

    func requestVerificationCode(for rawPhoneNumber: String) throws {
        let phoneNumber = try Self.normalizedPhoneNumber(rawPhoneNumber)
        let code = codeGenerator()

        pendingPhoneNumber = phoneNumber
        pendingCode = code
        verificationExpiresAt = now().addingTimeInterval(5 * 60)
        developmentVerificationCode = code
        statusMessage = "验证码已生成，5 分钟内有效"
    }

    func verify(phone rawPhoneNumber: String, code rawCode: String) throws {
        let phoneNumber = try Self.normalizedPhoneNumber(rawPhoneNumber)
        guard let pendingPhoneNumber, !pendingCode.isEmpty, let verificationExpiresAt else {
            throw LoginError.codeNotRequested
        }
        guard pendingPhoneNumber == phoneNumber else {
            throw LoginError.phoneNumberChanged
        }
        guard now() <= verificationExpiresAt else {
            clearPendingVerification()
            throw LoginError.codeExpired
        }

        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code == pendingCode else {
            throw LoginError.codeMismatch
        }

        boundPhoneNumber = phoneNumber
        persistence.saveBoundPhoneNumber(phoneNumber)
        clearPendingVerification()
        statusMessage = "手机号已绑定"
    }

    func signOut() {
        boundPhoneNumber = nil
        persistence.clearBoundPhoneNumber()
        clearPendingVerification()
        statusMessage = "已退出登录"
    }

    private func clearPendingVerification() {
        pendingPhoneNumber = nil
        pendingCode = ""
        verificationExpiresAt = nil
        developmentVerificationCode = nil
    }

    nonisolated static func normalizedPhoneNumber(_ rawPhoneNumber: String) throws -> String {
        let phoneNumber = rawPhoneNumber.filter(\.isNumber)
        let pattern = #"^1[3-9]\d{9}$"#
        guard phoneNumber.range(of: pattern, options: .regularExpression) != nil else {
            throw LoginError.invalidPhoneNumber
        }
        return phoneNumber
    }

    nonisolated static func maskPhoneNumber(_ phoneNumber: String) -> String {
        guard phoneNumber.count == 11 else { return phoneNumber }
        let prefix = phoneNumber.prefix(3)
        let suffix = phoneNumber.suffix(4)
        return "\(prefix)****\(suffix)"
    }

    nonisolated private static func generateVerificationCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}
