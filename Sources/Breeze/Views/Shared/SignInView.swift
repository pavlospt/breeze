import BreezeKit
import SwiftUI

struct SignInView: View {
    @Environment(ACController.self) private var controller
    var compact = false

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool { !email.isEmpty && !password.isEmpty && !controller.isSigningIn }

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            AppBadge(size: compact ? 48 : 64)

            VStack(spacing: 4) {
                Text("Welcome to Breeze")
                    .font(.system(size: compact ? 17 : 22, weight: .semibold))
                Text("Sign in with your TCL Home account")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .modifier(GlassField())
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submit)
                    .modifier(GlassField())
            }

            Button(action: submit) {
                HStack {
                    if controller.isSigningIn {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text("Sign In").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(ACMode.cool.tint).interactive(), in: .capsule)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSubmit)

            if let message = controller.errorMessage {
                ErrorBanner(message: message)
            }

            Text("Signed in with Google? Set a password via “Forgot password” in TCL Home first.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .onAppear { focusedField = .email }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await controller.signIn(email: email, password: password) }
    }
}

private struct GlassField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }
}

/// The app's snowflake mark, used on the sign-in screen and in Settings.
struct AppBadge: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: ACMode.cool.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: ACMode.cool.tint.opacity(0.5), radius: size * 0.2)
            Image(systemName: "snowflake")
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
