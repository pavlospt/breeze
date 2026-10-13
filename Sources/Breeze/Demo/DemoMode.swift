import BreezeKit
import Foundation

/// Launch-argument driven demo, used for screenshots and the README video.
///
///     open Breeze.app --args --demo          # sample devices, no account needed
///     open Breeze.app --args --demo-tour     # same, plus a scripted walkthrough
enum DemoMode {
    static let isTour = ProcessInfo.processInfo.arguments.contains("--demo-tour")
    static let isEnabled = isTour || ProcessInfo.processInfo.arguments.contains("--demo")

    @MainActor static func makeController() -> ACController {
        // Separate defaults domain so demo runs never touch the real app's settings.
        let defaults = UserDefaults(suiteName: "com.ptournaris.Breeze.demo") ?? .standard
        defaults.removePersistentDomain(forName: "com.ptournaris.Breeze.demo")
        return ACController(
            credentialStore: InMemoryCredentialStore(Credentials(email: "demo@example.com", password: "demo")),
            defaults: defaults,
            makeService: { _ in DemoACService() })
    }
}

/// A scripted walkthrough of the main controls, driven through the real controller.
@MainActor
enum DemoTour {
    static func run(_ controller: ACController) async {
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func select(_ id: String) { controller.selectedID = id }
        func fan(_ name: String) {
            if let speed = controller.profile.fanSpeeds.first(where: { $0.name == name }) {
                controller.send(speed.command)
            }
        }
        func feature(_ name: String) {
            if let f = controller.profile.features.first(where: { $0.name == name }) {
                controller.send(f.isOn(in: controller.state) ? f.offCommand : f.onCommand)
            }
        }
        func sweepTemperature(to target: Int) async {
            while let current = controller.state.targetTemperature, current != target {
                controller.adjustTemperature(by: target > current ? 1 : -1)
                await pause(0.22)
            }
        }

        while controller.phase != .ready { await pause(0.2) }
        select("living")
        // Leaves time for scripts/record-demo.sh to start recording on the initial state.
        await pause(7)

        // Cooling down the living room.
        await sweepTemperature(to: 19)
        await pause(0.8)
        fan("High")
        await pause(1.2)
        feature("Eco")
        await pause(1.4)

        // Switch to heat and warm up.
        controller.setMode(.heat)
        await pause(1.0)
        await sweepTemperature(to: 25)
        await pause(1.0)
        fan("Auto")
        await pause(1.4)

        // Bedroom: turn it on, dry mode.
        select("bedroom")
        await pause(1.4)
        controller.setPower(true)
        await pause(1.2)
        controller.setMode(.dry)
        await pause(1.2)
        feature("Sleep")
        await pause(1.4)

        // Office: cool with turbo.
        select("office")
        await pause(1.4)
        controller.setMode(.cool)
        await pause(1.0)
        fan("Turbo")
        await pause(1.0)
        feature("Swing")
        await pause(1.6)

        // Back to the living room, then off.
        select("living")
        await pause(1.6)
        controller.setPower(false)
        await pause(1.6)
        controller.setPower(true)
        controller.setMode(.cool)
        await pause(0.8)
        await sweepTemperature(to: 22)
        await pause(2)
    }
}
