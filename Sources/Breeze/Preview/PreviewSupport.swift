#if DEBUG
import BreezeKit
import SwiftUI

extension ACController {
    @MainActor static func preview(signedIn: Bool = true) -> ACController {
        ACController(
            credentialStore: InMemoryCredentialStore(
                signedIn ? Credentials(email: "preview@example.com", password: "x") : nil),
            makeService: { _ in DemoACService() })
    }
}

// `PreviewProvider` rather than `#Preview` so the package also builds with the
// Command Line Tools, which don't ship the Previews macro plugin. Xcode renders both.
struct BreezePreviews: PreviewProvider {
    static var previews: some View {
        MainWindow()
            .environment(ACController.preview())
            .frame(width: 920, height: 640)
            .previewDisplayName("Window")

        MainWindow()
            .environment(ACController.preview())
            .frame(width: 460, height: 700)
            .previewDisplayName("Window – narrow")

        MenuBarPanel()
            .environment(ACController.preview())
            .previewDisplayName("Menu bar panel")

        MainWindow()
            .environment(ACController.preview(signedIn: false))
            .frame(width: 600, height: 600)
            .previewDisplayName("Sign in")
    }
}
#endif
