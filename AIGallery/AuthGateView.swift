import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var session: UserSession

    var body: some View {
        Group {
            if session.isAuthenticated {
                ContentView()
            } else {
                PhoneLoginView()
            }
        }
        .animation(.snappy, value: session.isAuthenticated)
    }
}

private struct PhoneLoginView: View {
    @EnvironmentObject private var session: UserSession
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 28)

                header

                VStack(spacing: 14) {
                    phoneField
                    codeField
                    primaryButton
                }

                if let code = session.developmentVerificationCode {
                    Text("本机验证码 \(code)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.galleryWarmGray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Text(errorMessage.isEmpty ? session.statusMessage : errorMessage)
                    .font(.footnote)
                    .foregroundStyle(errorMessage.isEmpty ? .secondary : Color.galleryRed)
                    .frame(minHeight: 20, alignment: .leading)

                Spacer()

                Text("绑定后会在本机保存账号状态、收藏作品和点赞记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .background(Color.galleryBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)

            Text("登录 AI 画廊")
                .font(.system(size: 30, weight: .bold))

            Text("首次进入需要绑定手机号，通过验证码确认后即可保存收藏和点赞。")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var phoneField: some View {
        TextField("手机号", text: $phoneNumber)
            .keyboardType(.numberPad)
            .textContentType(.telephoneNumber)
            .font(.body)
            .padding(15)
            .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.galleryWarmGray, lineWidth: 1)
            }
    }

    private var codeField: some View {
        HStack(spacing: 10) {
            TextField("验证码", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.body)

            Button("获取验证码") {
                requestCode()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.galleryWarmGray, lineWidth: 1)
        }
    }

    private var primaryButton: some View {
        Button {
            verify()
        } label: {
            Text("绑定并进入")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func requestCode() {
        do {
            try session.requestVerificationCode(for: phoneNumber)
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verify() {
        do {
            try session.verify(phone: phoneNumber, code: verificationCode)
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(UserSession())
        .environmentObject(GalleryLibrary())
}
