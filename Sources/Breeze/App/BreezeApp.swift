import SwiftUI

@main
struct BreezeApp: App {
    @State private var controller = DemoMode.isEnabled ? DemoMode.makeController() : ACController()
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some Scene {
        Window("Breeze", id: SceneID.main) {
            MainWindow()
                .environment(controller)
                .task {
                    if DemoMode.isTour { await DemoTour.run(controller) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 920, height: 660)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") { Task { await controller.reload() } }
                    .keyboardShortcut("r")
                    .disabled(controller.phase == .signedOut)
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environment(controller)
        } label: {
            MenuBarLabel()
                .environment(controller)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(controller)
                .environment(launchAtLogin)
        }
    }
}

enum SceneID {
    static let main = "main"
}
